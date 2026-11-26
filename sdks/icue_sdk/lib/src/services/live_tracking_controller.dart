import 'dart:async';
import 'dart:math';

import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:icue_sdk/src/models/live_data.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';

/// Orchestrates live-tracking data polling and generates smooth 60 fps
/// animations for the UI to consume via [ValueNotifier]s.
class LiveTrackingController extends WidgetsBindingObserver {
  LiveTrackingController({
    this.provider,
    required this.vsync,
    required this.student,
  });

  final VehicleProvider? provider;
  final TickerProvider vsync;
  final User student;

  // --- Public notifiers consumed by the UI ---
  final ValueNotifier<Set<Marker>> markersNotifier = ValueNotifier({});
  final ValueNotifier<Set<Polyline>> polylinesNotifier = ValueNotifier({});
  final ValueNotifier<Set<Circle>> circlesNotifier = ValueNotifier({});
  final ValueNotifier<LatLng?> cameraTargetNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(true);

  /// Emits `true` when GPS signal is considered lost (2+ consecutive offline
  /// polls) and `false` when it recovers.  The UI page can display a banner.
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier(false);

  // --- Engine state ---
  bool _isDisposed = false;
  bool _isTrackingEnabled = false;
  bool _isPollingActive = false;

  // Animations
  AnimationController? _busAnimationController;
  AnimationController? _pulseController;
  Animation<double>? _busAnimation;
  Animation<double>? _pulseRadiusAnimation;

  // Icons
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _busOffIcon;
  BitmapDescriptor? _schoolIcon;
  BitmapDescriptor? _studentIcon;
  BitmapDescriptor? _stopIcon;

  // Position state
  LatLng? _previousBusPosition;
  LatLng? _targetBusPosition;
  LatLng? _currentAnimatedBusPosition;
  List<LatLng> _currentPathSegments = [];
  double _totalPathDistance = 0;
  double _currentRotation = 0;
  int _lastNearestPointIndex = 0;
  List<LatLng> _polylineCoords = [];
  LiveData? _latestData;

  // Static marker cache: _updateBusMarker spreads this set directly
  // instead of iterating the full marker set at 60 fps.
  Set<Marker> _staticMarkersCache = {};

  // --- Marker emission deduplication (prevents blinking) ---
  // Caches the last values written to markersNotifier so we can skip
  // writes that would produce a visually identical marker set.
  LatLng? _lastEmittedPosition;
  double _lastEmittedRotation = -1;
  bool _lastEmittedHasNetwork = true;
  bool _staticMarkersDirty = true; // force first emission

  // --- Network icon debounce (prevents single-poll blink) ---
  int _offlinePollCount = 0;
  bool _effectiveHasNetwork = true;

  // O(1) path segment traversal: advance index monotonically since
  // animation t always increases within one cycle.
  int _animSegmentIndex = 0;
  double _animCumulativeDist = 0.0;

  // Dead reckoning via vsync Ticker (frame-synchronized, no Timer
  // stutter). Keeps the bus moving between polls.
  Ticker? _deadReckoningTicker;
  double _drLastElapsedSecs = 0.0;
  static const Duration _drMaxDuration = Duration(seconds: 3);
  double _lastBearingDeg = 0; // geographic bearing (not display rotation)
  bool _shouldDeadReckon = false;
  double _lastSpeedMps = 0; // km/h → m/s conversion done at poll time

  // Time-delta clamped angular velocity makes rotation
  // frame-rate independent and removes the discontinuous segT < 0.2 branch.
  static const double _rotDegsPerSec = 200.0;
  int _lastAnimTickMicros = 0; // for per-frame dt computation

  // EMA-smoothed target rotation: damps look-ahead bearing micro-oscillation
  // that occurs as the bus crosses polyline segment boundaries each frame.
  double _smoothedTargetRotation = 0;
  // 60 m look-ahead averages out more consecutive micro-kinks than 30 m did.
  static const double _lookAheadMeters = 60.0;

  int _lastCircleUpdateMs = 0;

  // Throttle GoogleMap widget rebuilds to ~30 fps.  The plugin's platform
  // channel can't keep up with 60 fps marker diffs – intermediate states
  // where the old marker is removed before the new one is placed cause the
  // visible "jump" effect.
  int _lastMarkerEmitMs = 0;
  static const int _mapUpdateThrottleMs = 33; // ~30 fps

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void init() {
    WidgetsBinding.instance.addObserver(this);

    // Bus movement animation – 4900 ms matches the 5 s poll with a small buffer.
    _busAnimationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 4900),
    );
    _busAnimation = CurvedAnimation(
      parent: _busAnimationController!,
      curve: Curves.linear,
    );
    _busAnimation!.addListener(_onBusAnimationTick);

    // Trigger dead reckoning when the current animation finishes.
    _busAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onBusAnimationCompleted();
    });

    // Pulse circle animation
    _pulseController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 2),
    );
    _pulseRadiusAnimation = Tween<double>(begin: 0.0, end: 30.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    // Only update the circle via the pulse controller when the bus animation is
    // NOT running. When the bus IS animating, _onBusAnimationTick calls
    // _updatePulseCircle itself (after the position is updated), giving exactly
    // one circle update per frame instead of two.
    _pulseController!.addListener(() {
      if (_busAnimationController?.isAnimating != true) {
        _updatePulseCircle();
      }
    });
    _pulseController!.repeat();

    Future.microtask(() {
      if (!_isDisposed) {
        startTracking(clearAllData: true);
      }
    });
  }

  void updateIcons({
    BitmapDescriptor? bus,
    BitmapDescriptor? busOff,
    BitmapDescriptor? school,
    BitmapDescriptor? student,
    BitmapDescriptor? stop,
  }) {
    _busIcon = bus;
    _busOffIcon = busOff;
    _schoolIcon = school;
    _studentIcon = student;
    _stopIcon = stop;

    if (_latestData != null) {
      _updateStaticMarkers(_latestData!);
      _updateBusMarker();
    }
  }

  void dispose() {
    _isDisposed = true;
    _isTrackingEnabled = false;
    _deadReckoningTicker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _busAnimationController?.dispose();
    _pulseController?.dispose();
    markersNotifier.dispose();
    polylinesNotifier.dispose();
    circlesNotifier.dispose();
    cameraTargetNotifier.dispose();
    isOfflineNotifier.dispose();
    isLoadingNotifier.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startTracking();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stopTracking();
    }
  }

  Future<void> startTracking({bool clearAllData = false}) async {
    if (_isTrackingEnabled) return;
    _isTrackingEnabled = true;
    if (clearAllData) {
      await provider?.clearAllData(clearMsg: true, clearHive: false);
    }

    isLoadingNotifier.value = true;

    if (provider != null) {
      if (provider!.liveData != null) {
        _processNewTickData(provider!.liveData!);
      }

      if (!_isTrackingEnabled || _isDisposed) return;

      await provider!.getVehicleLocation(student: student);
    }

    if (!_isTrackingEnabled || _isDisposed) return;
    unawaited(_startPollingLoop());
  }

  void stopTracking() {
    _isTrackingEnabled = false;
    _busAnimationController?.stop();
    _deadReckoningTicker?.stop();
  }

  /// Current smoothed bus position (polyline-snapped, animated).
  /// Use this in the Recenter FAB instead of reading raw GPS from the provider.
  LatLng? get currentBusPosition => _currentAnimatedBusPosition;

  // ---------------------------------------------------------------------------
  // Polling loop
  // ---------------------------------------------------------------------------

  Future<void> _startPollingLoop() async {
    if (_isPollingActive) return;
    _isPollingActive = true;

    while (_isTrackingEnabled && !_isDisposed) {
      try {
        final stopwatch = Stopwatch()..start();

        final newData = await provider?.getVehicleLocation(
          isPolling: true,
          student: student,
        );

        final routeEnded = provider?.routeEnded == true;

        if (routeEnded) {
          stopTracking();
          isLoadingNotifier.value = false;
          break;
        }

        if (!_isDisposed && _isTrackingEnabled) {
          isLoadingNotifier.value = false;
          if (newData != null) _processNewTickData(newData);
        }

        final pollInterval = _computePollInterval();
        final timeToWait = pollInterval - stopwatch.elapsed;
        if (timeToWait > Duration.zero && !_isDisposed && _isTrackingEnabled) {
          await Future<void>.delayed(timeToWait);
        }
      } catch (e, s) {
        debugPrint('Polling error: $e $s');
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    _isPollingActive = false;
  }

  /// Adaptive poll interval:
  /// - 10 s when bus is stopped (save battery & data)
  /// - 3 s when bus is near the student's stop (parent cares most)
  /// - 5 s otherwise (normal tracking)
  Duration _computePollInterval() {
    final data = _latestData;
    if (data == null) return const Duration(seconds: 5);

    // Bus is stopped.
    if (data.speed.round() == 0) {
      return const Duration(seconds: 10);
    }

    // Bus is near the student's pickup/drop point.
    if (data.studentPoint != null &&
        data.studentPoint!.coordinates.isNotEmpty &&
        _currentAnimatedBusPosition != null) {
      final studentPos = LatLng(
        data.studentPoint!.coordinates.first,
        data.studentPoint!.coordinates.last,
      );
      final distToStudent = distanceMeters(
        _currentAnimatedBusPosition!,
        studentPos,
      );
      if (distToStudent < 500) {
        return const Duration(seconds: 3);
      }
    }

    return const Duration(seconds: 5);
  }

  // ---------------------------------------------------------------------------
  // Per-tick processing
  // ---------------------------------------------------------------------------

  void _processNewTickData(LiveData live) {
    // Real data arrived – stop dead reckoning immediately.
    _deadReckoningTicker?.stop();

    // Debounce network-icon swap: require 2+ consecutive offline polls
    // before switching to the offline icon.  A single stale poll (network
    // hiccup) won't flash the icon.
    if (live.hasNetwork) {
      if (_offlinePollCount >= 2 && !_effectiveHasNetwork) {
        // Transitioning back online – notify UI.
        isOfflineNotifier.value = false;
      }
      _offlinePollCount = 0;
      _effectiveHasNetwork = true;
    } else {
      _offlinePollCount++;
      if (_offlinePollCount >= 2) {
        _effectiveHasNetwork = false;
        isOfflineNotifier.value = true;
      }
    }

    _latestData = live;
    _updatePolyline(live);
    _updateStaticMarkers(live);
    _updateAndAnimateBus(live);
  }

  void _updatePolyline(LiveData live) {
    if (_polylineCoords.length == live.polylineCoordinates.length &&
        (_polylineCoords.isEmpty ||
            _polylineCoords.first == live.polylineCoordinates.first)) {
      return; // Route unchanged – skip rebuild.
    }
    _polylineCoords = live.polylineCoordinates;
    _lastNearestPointIndex = 0;
    polylinesNotifier.value = _buildPolylineSet();
  }

  /// Builds the full-route polyline set as a uniform border + fill pair.
  Set<Polyline> _buildPolylineSet() {
    if (_polylineCoords.length < 2) return {};

    return {
      // Border (wider, darker blue)
      Polyline(
        polylineId: const PolylineId('route_border'),
        points: _polylineCoords,
        width: 7,
        color: Colors.blue.shade800,
        geodesic: true,
      ),
      // Fill (narrower, vivid blue)
      Polyline(
        polylineId: const PolylineId('route'),
        points: _polylineCoords,
        width: 4,
        color: Colors.blue.shade400,
        geodesic: true,
        zIndex: 1,
      ),
    };
  }

  void _updateStaticMarkers(LiveData live) {
    final Set<Marker> statics = {};

    // School
    if (live.studentPoint != null && _schoolIcon != null) {
      // Normally we pull student school pos from hive here. We'll simplify using the mock point logic.
      // E.g. add school marker
      // statics.add(
      //   Marker(
      //     markerId: const MarkerId('school'),
      //     position: LatLng(
      //       live.studentPoint!.coordinates.first,
      //       live.studentPoint!.coordinates.last,
      //     ),
      //     icon: _schoolIcon!,
      //     infoWindow: InfoWindow(
      //       title: live.studentPoint!.pickPoint ?? 'Pickup',
      //       snippet: 'Your Point',
      //     ),
      //     zIndexInt: 2,
      //   ),
      // );
    }

    if (live.studentPoint?.coordinates.isNotEmpty == true &&
        _studentIcon != null) {
      statics.add(
        Marker(
          markerId: const MarkerId('student'),
          position: LatLng(
            live.studentPoint!.coordinates.first,
            live.studentPoint!.coordinates.last,
          ),
          icon: _studentIcon!,
          infoWindow: InfoWindow(
            title: live.studentPoint!.pickPoint ?? 'Pickup',
            snippet: 'Your Point',
          ),
          zIndexInt: 2,
        ),
      );
    }

    // Bus Stops
    if (live.busStops != null) {
      for (final stop in live.busStops!) {
        if (stop.coordinates.isEmpty) continue;

        // Skip if this is the student's own pickup/drop point to avoid dual markers
        if (live.studentPoint != null &&
            live.studentPoint!.coordinates.isNotEmpty &&
            stop.coordinates.first == live.studentPoint!.coordinates.first &&
            stop.coordinates.last == live.studentPoint!.coordinates.last) {
          continue;
        }

        statics.add(
          Marker(
            markerId: MarkerId(
              'stop_${stop.pickPoint ?? stop.landMark ?? stop.coordinates.join(',')}',
            ),
            position: LatLng(stop.coordinates.first, stop.coordinates.last),
            icon: _stopIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            infoWindow: InfoWindow(
              title: stop.pickPoint ?? 'Stop',
              snippet: stop.landMark,
            ),
            zIndexInt: 1,
          ),
        );
      }
    }

    // Cache once; _updateBusMarker uses it at 60 fps without iteration.
    // Mark dirty so the next _updateBusMarker emission is not suppressed.
    if (!setEquals(_staticMarkersCache, statics)) {
      _staticMarkersDirty = true;
    }
    _staticMarkersCache = statics;
  }

  void _updateAndAnimateBus(LiveData live) {
    if (_busIcon == null || _busOffIcon == null) return;

    final rawGpsPos = LatLng(
      live.coordinates.firstOrNull ?? 0,
      live.coordinates.lastOrNull ?? 0,
    );

    // Save the current index BEFORE the call.  _getNearestPolylinePoint always
    // writes _lastNearestPointIndex regardless of whether the bus is on-route or
    // off-route.  If the bus is off-route we must restore the saved value so
    // future search windows remain anchored to the last known good position
    // rather than drifting to whichever polyline segment happened to be nearest
    // to the off-route GPS reading.
    final int savedNearestIndex = _lastNearestPointIndex;
    final mappedPos = _getNearestPolylinePoint(
      rawGpsPos,
      live.polylineCoordinates,
    );

    // Initial placement.
    if (_previousBusPosition == null || _currentAnimatedBusPosition == null) {
      _previousBusPosition = mappedPos;
      _currentAnimatedBusPosition = mappedPos;
      _targetBusPosition = mappedPos;
      _currentRotation = 0;
      _currentPathSegments = [mappedPos, mappedPos];
      cameraTargetNotifier.value = mappedPos;
      _updateBusMarker();
      return;
    }

    final dist = distanceMeters(
      _currentAnimatedBusPosition!,
      mappedPos,
    );

    // GPS noise threshold – discard micro-drifts to prevent jitter.
    // Lowered to 2.0m so slow movements (traffic, school zones) animate smoothly
    // instead of being filtered out and causing catching-up jumps later.
    if (dist < 2.0) {
      _debugLog('GPS jitter filtered: ${dist.toStringAsFixed(1)} m');
      _updateBusMarker();
      return;
    }

    // Prevent backward animation: dead reckoning can overshoot the target so
    // that the new GPS-snapped position is *behind* the current animated
    // position.  Instead of a hard snap (which causes a visible jump), use a
    // very short animation to glide back smoothly.
    if (dist < 20.0 && _lastBearingDeg != 0) {
      final dirToNew = bearingDegrees(
        _currentAnimatedBusPosition!,
        mappedPos,
      );
      final angDiff = ((dirToNew - _lastBearingDeg + 540) % 360) - 180;
      if (angDiff.abs() > 100) {
        _deadReckoningTicker?.stop();
        _debugLog(
          'Backward correction: angDiff=${angDiff.toStringAsFixed(1)}°',
        );

        // Smooth glide to corrected position over 300 ms instead of snapping.
        _previousBusPosition = _currentAnimatedBusPosition;
        _targetBusPosition = mappedPos;
        _currentPathSegments = [_currentAnimatedBusPosition!, mappedPos];
        _totalPathDistance = dist;
        _animSegmentIndex = 0;
        _animCumulativeDist = 0.0;
        _lastAnimTickMicros = 0;
        _smoothedTargetRotation = _currentRotation;
        // Suppress dead reckoning for backward corrections.
        _shouldDeadReckon = false;
        _busAnimationController?.duration = const Duration(milliseconds: 300);
        _busAnimationController?.forward(from: 0.0);
        return;
      }
    }

    // Store bearing + speed for dead reckoning.
    _lastBearingDeg = bearingDegrees(
      _currentAnimatedBusPosition!,
      mappedPos,
    );
    _lastSpeedMps = live.speed / 3.6; // km/h → m/s

    _debugLog(
      'Poll: dist=${dist.toStringAsFixed(1)} m  '
      'speed=${live.speed.toStringAsFixed(1)} km/h  '
      'bearing=${_lastBearingDeg.toStringAsFixed(1)}°',
    );

    // Build a smooth path through the polyline from current animated position
    // to the new GPS-snapped target.
    if (live.polylineCoordinates.length < 2) {
      _debugLog('Insufficient polyline data for path building.');
      _currentAnimatedBusPosition = mappedPos;
      _currentPathSegments = [mappedPos, mappedPos];
      _updateBusMarker();
      return;
    }

    _currentPathSegments = [_currentAnimatedBusPosition!];
    _totalPathDistance = 0;

    final int targetSegmentIndex = _lastNearestPointIndex;

    // Helper: Finds the closest segment index and distance to that segment.
    double getDistToSegment(LatLng pt, int i) {
      if (i < 0 || i >= live.polylineCoordinates.length - 1) {
        return double.infinity;
      }
      final p1 = live.polylineCoordinates[i];
      final p2 = live.polylineCoordinates[i + 1];
      final double l2 = pow(p2.latitude - p1.latitude, 2).toDouble() +
          pow(p2.longitude - p1.longitude, 2).toDouble();
      double t = 0.0;
      if (l2 != 0.0) {
        t = ((pt.latitude - p1.latitude) * (p2.latitude - p1.latitude) +
                (pt.longitude - p1.longitude) * (p2.longitude - p1.longitude)) /
            l2;
        t = t.clamp(0.0, 1.0);
      }
      final proj = LatLng(
        p1.latitude + t * (p2.latitude - p1.latitude),
        p1.longitude + t * (p2.longitude - p1.longitude),
      );
      return distanceMeters(pt, proj);
    }

    int currentSegmentIndex = savedNearestIndex;
    double currentMinD = double.infinity;
    final int curSearchStart = (savedNearestIndex - 25).clamp(
      0,
      max(0, live.polylineCoordinates.length - 2),
    );
    final int curSearchEnd = (savedNearestIndex + 25).clamp(
      0,
      max(0, live.polylineCoordinates.length - 1),
    );

    for (int i = curSearchStart; i < curSearchEnd; i++) {
      final d = getDistToSegment(_currentAnimatedBusPosition!, i);
      if (d < currentMinD) {
        currentMinD = d;
        currentSegmentIndex = i;
      }
    }

    if (currentMinD > 80.0) {
      // Fallback: search the entire polyline if the current animated position
      // has moved beyond the local search window.
      for (int i = 0; i < live.polylineCoordinates.length - 1; i++) {
        if (i >= curSearchStart && i < curSearchEnd) continue;
        final d = getDistToSegment(_currentAnimatedBusPosition!, i);
        if (d < currentMinD) {
          currentMinD = d;
          currentSegmentIndex = i;
        }
      }
    }

    final bool isCurrentlyOffRoute = currentMinD > 80.0;

    // We check if the newly mapped target is off route relative to actual GPS
    // If _getNearestPolylinePoint failed to snap due to >80m distance, then targetSegmentIndex
    // is the segment that got rejected, and its distance to rawGpsPos will be > 80.0.
    final bool isTargetOffRoute =
        getDistToSegment(rawGpsPos, targetSegmentIndex) > 80.0;

    // Restore the saved index when the target is off-route.
    // _getNearestPolylinePoint wrote _lastNearestPointIndex to whichever
    // polyline segment happened to be closest to the off-route GPS reading.
    // Keeping that value would shift the search window for the next tick away
    // from the bus's actual route position, causing the path builder to pull in
    // incorrect polyline waypoints and making the marker fly along the route
    // before snapping back.
    if (isTargetOffRoute) {
      _lastNearestPointIndex = savedNearestIndex;
    }

    // --- Off-route handling ---
    // When the target GPS position is off the polyline (>80 m from any segment),
    // there is no road geometry to follow.  Animate a straight line from the
    // current animated position to the raw GPS position so the marker glides
    // smoothly instead of jumping.  Dead reckoning is suppressed because
    // extrapolating off-road would send the bus into buildings.
    if (isTargetOffRoute) {
      _busAnimationController?.stop();
      _deadReckoningTicker?.stop();

      if (_currentAnimatedBusPosition != null && dist > 2) {
        // Same animation as on-route normal movement, just a straight line
        // path instead of polyline segments.
        _previousBusPosition = _currentAnimatedBusPosition;
        _targetBusPosition = mappedPos;
        _currentPathSegments = [_currentAnimatedBusPosition!, mappedPos];
        _totalPathDistance = dist;
        _animSegmentIndex = 0;
        _animCumulativeDist = 0.0;
        _lastAnimTickMicros = 0;
        _smoothedTargetRotation = _currentRotation;
        // Suppress dead reckoning – no polyline to extrapolate along.
        _shouldDeadReckon = false;
        _lastSpeedMps = 0;
        _busAnimationController?.duration =
            _computePollInterval() - const Duration(milliseconds: 100);
        _busAnimationController?.forward(from: 0.0);
        cameraTargetNotifier.value = mappedPos;
      } else {
        // Micro-movement or no previous position – snap immediately.
        _currentAnimatedBusPosition = mappedPos;
        _previousBusPosition = mappedPos;
        _currentPathSegments = [mappedPos, mappedPos];
        _lastSpeedMps = 0;
        _shouldDeadReckon = false;
        cameraTargetNotifier.value = mappedPos;
        _updateBusMarker();
      }
      _debugLog('Off-route glide: dist=${dist.toStringAsFixed(1)} m');
      return;
    }

    if (!isCurrentlyOffRoute &&
        !isTargetOffRoute &&
        currentSegmentIndex <= targetSegmentIndex) {
      // Add topological intermediate nodes between current and target segments.
      // If they lie on the exact same segment, this loop structurally skips,
      // generating pristine 0-node interpolation (no back-and-forth node visits).
      for (int i = currentSegmentIndex + 1; i <= targetSegmentIndex; i++) {
        if (distanceMeters(
              _currentPathSegments.last,
              live.polylineCoordinates[i],
            ) >
            2.0) {
          _currentPathSegments.add(live.polylineCoordinates[i]);
        }
      }
    }

    if (_currentPathSegments.last != mappedPos) {
      _currentPathSegments.add(mappedPos);
    }

    for (int i = 0; i < _currentPathSegments.length - 1; i++) {
      _totalPathDistance += distanceMeters(
        _currentPathSegments[i],
        _currentPathSegments[i + 1],
      );
    }

    // Detect massive polyline detours (e.g. intersecting loops).
    // If the traced polyline path implies an impossible speed (>250m in 5s)
    // or is absurdly longer than the straight-line distance, flatten the path.
    // This stops the bus from moving "very fast back and forth in the path".
    if (_totalPathDistance > dist * 3 + 100 || _totalPathDistance > 250) {
      _currentPathSegments = [_currentAnimatedBusPosition!, mappedPos];
      _totalPathDistance = dist;
    }

    _previousBusPosition = _currentAnimatedBusPosition;
    _targetBusPosition = mappedPos;

    if (dist > 1500) {
      // Truly massive jump – hard snap (genuine GPS error / route change).
      _currentAnimatedBusPosition = mappedPos;
      _currentPathSegments = [mappedPos, mappedPos];
      cameraTargetNotifier.value = mappedPos;
      _updateBusMarker();
    } else if (dist > 500) {
      // Large jump (500–1500 m) – smooth over 800 ms instead of hard snap.
      // Likely a GPS reacquisition or catch-up after network delay.
      _previousBusPosition = _currentAnimatedBusPosition;
      _targetBusPosition = mappedPos;
      _currentPathSegments = [_currentAnimatedBusPosition!, mappedPos];
      _totalPathDistance = dist;
      _animSegmentIndex = 0;
      _animCumulativeDist = 0.0;
      _lastAnimTickMicros = 0;
      _smoothedTargetRotation = _currentRotation;
      // Suppress dead reckoning for large catch-up jumps.
      _shouldDeadReckon = false;
      _busAnimationController?.duration = const Duration(milliseconds: 800);
      _busAnimationController?.forward(from: 0.0);
      cameraTargetNotifier.value = mappedPos;
    } else if (_totalPathDistance > 2) {
      // Normal movement – reset O(1) traversal cache and start animation.
      _animSegmentIndex = 0;
      _animCumulativeDist = 0.0;
      _lastAnimTickMicros = 0; // reset dt so first tick doesn't spike
      _smoothedTargetRotation = _currentRotation; // sync EMA to current heading
      // Enable dead reckoning only for normal poll-interval animations.
      _shouldDeadReckon = true;
      _busAnimationController?.duration =
          _computePollInterval() - const Duration(milliseconds: 100);
      _busAnimationController?.forward(from: 0.0);
      cameraTargetNotifier.value = mappedPos;
    } else {
      // Micro-movement – snap without animating.
      _currentAnimatedBusPosition = mappedPos;
      _currentRotation = busRotation(
        _previousBusPosition!,
        mappedPos,
      );
      _updateBusMarker();
    }
  }

  // ---------------------------------------------------------------------------
  // Dead reckoning
  // ---------------------------------------------------------------------------

  void _onBusAnimationCompleted() {
    if (!_shouldDeadReckon) return;
    if (_lastSpeedMps < 0.5) return; // Stopped – nothing to extrapolate.
    _deadReckoningTicker?.dispose();
    _drLastElapsedSecs = 0.0;
    _deadReckoningTicker = vsync.createTicker(_deadReckoningTick)..start();
    _debugLog(
      'DR start: ${_lastSpeedMps.toStringAsFixed(1)} m/s  '
      'bearing=${_lastBearingDeg.toStringAsFixed(1)}°',
    );
  }

  void _deadReckoningTick(Duration elapsed) {
    if (_isDisposed) {
      _deadReckoningTicker?.stop();
      return;
    }
    if (elapsed > _drMaxDuration) {
      _deadReckoningTicker?.stop();
      _debugLog('DR stop: exceeded ${_drMaxDuration.inSeconds} s');
      return;
    }
    if (_currentAnimatedBusPosition == null) return;

    final totalSecs = elapsed.inMicroseconds / 1e6;
    final dtSecs = totalSecs - _drLastElapsedSecs;
    _drLastElapsedSecs = totalSecs;

    final distThisFrame = _lastSpeedMps * dtSecs;
    if (distThisFrame < 0.02) return; // Skip sub-centimeter updates.

    _currentAnimatedBusPosition = extrapolate(
      _currentAnimatedBusPosition!,
      _lastBearingDeg,
      distThisFrame,
    );
    _updateBusMarkerThrottled();
  }

  // ---------------------------------------------------------------------------
  // 60 fps animation tick
  // ---------------------------------------------------------------------------

  void _onBusAnimationTick() {
    if (_isDisposed ||
        _previousBusPosition == null ||
        _targetBusPosition == null ||
        _busAnimation == null) {
      return;
    }

    // Compute real elapsed time since last tick so rotation
    // speed is consistent regardless of actual frame rate.
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final dtSecs = _lastAnimTickMicros == 0
        ? 1 / 60.0
        : (nowMicros - _lastAnimTickMicros) / 1e6;
    _lastAnimTickMicros = nowMicros;
    final maxRotDelta = _rotDegsPerSec * dtSecs;

    final t = _busAnimation!.value;

    if (_currentPathSegments.length <= 1) {
      _currentAnimatedBusPosition = interpolateLatLng(
        _previousBusPosition!,
        _targetBusPosition!,
        t,
      );
    } else {
      final double targetDistance = _totalPathDistance * t;

      // Advance only forward (O(1) amortised vs O(n) per frame).
      while (_animSegmentIndex < _currentPathSegments.length - 2) {
        final segDist = distanceMeters(
          _currentPathSegments[_animSegmentIndex],
          _currentPathSegments[_animSegmentIndex + 1],
        );
        if (_animCumulativeDist + segDist >= targetDistance) break;
        _animCumulativeDist += segDist;
        _animSegmentIndex++;
      }

      final p1 = _currentPathSegments[_animSegmentIndex];
      final p2 = _currentPathSegments[_animSegmentIndex + 1];
      final segDist = distanceMeters(p1, p2);
      final segT = segDist > 0.1
          ? ((targetDistance - _animCumulativeDist) / segDist).clamp(0.0, 1.0)
          : 1.0;

      _currentAnimatedBusPosition = interpolateLatLng(p1, p2, segT);

      // Look-ahead bearing: compute heading toward a point 60 m ahead on the
      // path rather than using the current segment endpoints.  An EMA on the
      // target rotation damps micro-kink oscillation (bearing changes a few
      // degrees every time _animSegmentIndex increments) without slowing the
      // bus's response to genuine turns.
      final lookAheadPt = _getLookAheadPoint(_lookAheadMeters);
      if (lookAheadPt != null) {
        final laDist = distanceMeters(
          _currentAnimatedBusPosition!,
          lookAheadPt,
        );
        if (laDist > 2.0) {
          final rawTargetRotation = busRotation(
            _currentAnimatedBusPosition!,
            lookAheadPt,
          );
          // EMA blend with α=0.2 (≈5-frame half-life at 60 fps).
          // Shortest-arc diff prevents wrap-around artifacts (359° → 1°).
          double diff = rawTargetRotation - _smoothedTargetRotation;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;
          _smoothedTargetRotation =
              (_smoothedTargetRotation + diff * 0.2 + 360) % 360;
          _currentRotation = _stepRotation(
            _currentRotation,
            _smoothedTargetRotation,
            maxRotDelta,
          );
        }
      }
    }

    _updateBusMarkerThrottled();
  }

  /// Returns a point [distMeters] ahead of the current animated bus position
  /// along [_currentPathSegments], starting from [_animSegmentIndex].
  /// Returns the last path point if the remaining route is shorter than
  /// [distMeters].
  LatLng? _getLookAheadPoint(double distMeters) {
    if (_currentAnimatedBusPosition == null) return null;
    if (_currentPathSegments.length < 2) return null;

    double remaining = distMeters;
    for (int i = _animSegmentIndex; i < _currentPathSegments.length - 1; i++) {
      final p1 = i == _animSegmentIndex
          ? _currentAnimatedBusPosition!
          : _currentPathSegments[i];
      final p2 = _currentPathSegments[i + 1];
      final d = distanceMeters(p1, p2);
      if (d >= remaining) {
        return interpolateLatLng(p1, p2, remaining / d);
      }
      remaining -= d;
    }
    return _currentPathSegments.last;
  }

  /// Moves [from] toward [to] by at most [maxDelta] degrees, respecting the
  /// 359° → 0° wrap.  Returns a value in [0, 360).
  double _stepRotation(double from, double to, double maxDelta) {
    double diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final clamped = diff.clamp(-maxDelta, maxDelta);
    final r = (from + clamped) % 360;
    return r < 0 ? r + 360 : r;
  }

  // ---------------------------------------------------------------------------
  // Marker / circle helpers
  // ---------------------------------------------------------------------------

  void _updatePulseCircle() {
    if (_isDisposed || _currentAnimatedBusPosition == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCircleUpdateMs < 150) {
      return;
    }
    _lastCircleUpdateMs = now;

    circlesNotifier.value = {
      Circle(
        circleId: const CircleId('bus_pulse'),
        center: _currentAnimatedBusPosition!,
        radius: _pulseRadiusAnimation?.value ?? 0,
        fillColor: Colors.blue.withValues(alpha: 0.15),
        strokeColor: Colors.blue.withValues(alpha: 0.3),
        strokeWidth: 2,
        zIndex: 5,
      ),
    };
  }

  /// Throttled wrapper: marks the marker dirty and only flushes the update
  /// if at least [_mapUpdateThrottleMs] have elapsed since the last emit.
  /// This coalesces the 60 fps animation ticks into ~30 fps GoogleMap rebuilds
  /// so the platform channel has time to complete each marker diff before the
  /// next one arrives.
  void _updateBusMarkerThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMarkerEmitMs < _mapUpdateThrottleMs) return;
    _flushBusMarker();
    // Also update the pulse circle in the same frame to avoid a second
    // GoogleMap rebuild from the circles notifier.
    _updatePulseCircle();
  }

  /// Unconditional marker flush – bypasses the throttle.  Used at key moments
  /// (initial placement, off-route snap, micro-movement snap) where the marker
  /// must be placed immediately.
  void _updateBusMarker() {
    _flushBusMarker();
  }

  void _flushBusMarker() {
    if (_isDisposed ||
        _currentAnimatedBusPosition == null ||
        _latestData == null) {
      return;
    }

    // --- Emission deduplication: skip if nothing visually changed ---
    // Prevents the GoogleMap plugin from receiving a "new" marker set every
    // frame, which can trigger an internal remove→add that blinks the icon.
    final pos = _currentAnimatedBusPosition!;
    final rot = _currentRotation;
    final hasNet = _effectiveHasNetwork;

    if (!_staticMarkersDirty &&
        _lastEmittedPosition != null &&
        _lastEmittedHasNetwork == hasNet &&
        (rot - _lastEmittedRotation).abs() < 0.5 &&
        distanceMeters(pos, _lastEmittedPosition!) < 0.3) {
      return; // Visually identical – skip write.
    }

    _lastEmittedPosition = pos;
    _lastEmittedRotation = rot;
    _lastEmittedHasNetwork = hasNet;
    _staticMarkersDirty = false;
    _lastMarkerEmitMs = DateTime.now().millisecondsSinceEpoch;

    // spread cached static set + new bus marker.
    markersNotifier.value = {
      ..._staticMarkersCache,
      Marker(
        markerId: const MarkerId('bus'),
        position: pos,
        icon: hasNet ? _busIcon! : _busOffIcon!,
        anchor: const Offset(0.5, 0.5),
        rotation: rot,
        flat: true,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Polyline snapping
  // ---------------------------------------------------------------------------

  LatLng _getNearestPolylinePoint(
    LatLng vehiclePosition,
    List<LatLng> polylinePoints,
  ) {
    if (polylinePoints.isEmpty) return vehiclePosition;
    if (polylinePoints.length == 1) return polylinePoints.first;

    final int startIndex = (_lastNearestPointIndex - 5).clamp(
      0,
      polylinePoints.length - 2,
    );
    final int searchEnd = (_lastNearestPointIndex + 60).clamp(
      0,
      polylinePoints.length - 1,
    );

    LatLng bestPoint = polylinePoints[startIndex];
    double minAdjustedDistance = double.infinity;
    double bestRealDistance = double.infinity;
    int bestIndex = startIndex;
    const double distanceThreshold = 80;

    void checkSegment(int i, bool isFallback) {
      final p1 = polylinePoints[i];
      final p2 = polylinePoints[i + 1];
      final double l2 = pow(p2.latitude - p1.latitude, 2).toDouble() +
          pow(p2.longitude - p1.longitude, 2).toDouble();
      double t = 0.0;
      if (l2 != 0.0) {
        t = ((vehiclePosition.latitude - p1.latitude) *
                    (p2.latitude - p1.latitude) +
                (vehiclePosition.longitude - p1.longitude) *
                    (p2.longitude - p1.longitude)) /
            l2;
        t = t.clamp(0.0, 1.0);
      }
      final projection = LatLng(
        p1.latitude + t * (p2.latitude - p1.latitude),
        p1.longitude + t * (p2.longitude - p1.longitude),
      );
      final dist = distanceMeters(vehiclePosition, projection);

      // Index penalty strongly prefers points near the last known bus position
      // to avoid jumping to a nearby overlapping segment of the route (e.g. loops).
      final penalty = isFallback
          ? (i - _lastNearestPointIndex).abs() * 0.001
          : (i - _lastNearestPointIndex).abs() * 0.5;

      final adjustedDist = dist + penalty;

      if (adjustedDist < minAdjustedDistance) {
        minAdjustedDistance = adjustedDist;
        bestRealDistance = dist;
        bestPoint = projection;
        bestIndex = i;
      }
    }

    for (int i = startIndex; i < searchEnd; i++) {
      checkSegment(i, false);
    }

    if (bestRealDistance > distanceThreshold) {
      final localBestReal = bestRealDistance;
      final localBestIndex = bestIndex;
      final localBestPoint = bestPoint;

      minAdjustedDistance = double.infinity;
      bestRealDistance = double.infinity;

      for (int i = 0; i < polylinePoints.length - 1; i++) {
        if (i >= startIndex && i < searchEnd) continue;
        checkSegment(i, true);
      }

      if (bestRealDistance > localBestReal) {
        bestRealDistance = localBestReal;
        bestIndex = localBestIndex;
        bestPoint = localBestPoint;
      }
    }

    _lastNearestPointIndex = bestIndex;
    return bestRealDistance > distanceThreshold ? vehiclePosition : bestPoint;
  }

  // ---------------------------------------------------------------------------
  // Debug
  // ---------------------------------------------------------------------------

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[TrackingEngine] $message');
  }
}
