import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:icue_sdk/src/dialogs/tracking_info_dialog.dart';
import 'package:icue_sdk/src/models/live_data.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/models/vehicle_location.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';
import 'package:icue_sdk/src/services/live_tracking_controller.dart';
import 'package:icue_sdk/src/widgets/page_wrapper.dart';
import 'package:icue_sdk/src/widgets/tracking_overlays.dart';
import 'package:provider/provider.dart';

class LiveTrackingPage extends StatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with TickerProviderStateMixin {
  bool _autoRecenter = true;
  final ValueNotifier<bool> _defaultLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _defaultOfflineNotifier = ValueNotifier(false);
  bool _dialogShown = false;
  bool _duringRecenter = false;
  final ValueNotifier<Set<Circle>> _emptyCirclesNotifier = ValueNotifier({});
  final ValueNotifier<Set<Marker>> _emptyMarkersNotifier = ValueNotifier({});
  final ValueNotifier<Set<Polyline>> _emptyPolylinesNotifier = ValueNotifier(
    {},
  );

  GoogleMapController? _googleMap;
  bool _hasDoneInitialCamera = false;
  Timer? _mapGestureResetTimer;
  bool _mapReady = false;
  LatLng? _pendingCameraTarget;
  bool _showRecenterButton = false;
  LiveTrackingController? _trackingController;
  bool _userInitiatedMapGesture = false;
  late final UserProvider _userProvider;
  late final VehicleProvider _vehicleProv;

  @override
  void dispose() {
    _userProvider.removeListener(_onUserChanged);
    _vehicleProv.removeListener(_onData);
    _trackingController?.cameraTargetNotifier.removeListener(
      _onCameraTargetChanged,
    );
    _trackingController?.dispose();
    _mapGestureResetTimer?.cancel();
    _emptyMarkersNotifier.dispose();
    _emptyPolylinesNotifier.dispose();
    _emptyCirclesNotifier.dispose();
    _defaultLoadingNotifier.dispose();
    _defaultOfflineNotifier.dispose();
    _mapReady = false;
    _duringRecenter = false;
    _googleMap?.dispose();
    _googleMap = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _vehicleProv = context.read<VehicleProvider>();
    _userProvider = context.read<UserProvider>();

    if (_userProvider.user != null) {
      _initTrackingController(_userProvider.user!);
    } else {
      _userProvider.addListener(_onUserChanged);
    }
  }

  void _onUserChanged() {
    if (_userProvider.user != null && _trackingController == null) {
      _userProvider.removeListener(_onUserChanged);
      _initTrackingController(_userProvider.user!);
    }
  }

  void _initTrackingController(User student) {
    _trackingController = LiveTrackingController(
      provider: _vehicleProv,
      vsync: this,
      student: student,
    );

    _trackingController!.cameraTargetNotifier.addListener(
      _onCameraTargetChanged,
    );

    _trackingController!.init();
    _loadIcons();
    _vehicleProv.addListener(_onData);
    if (mounted) setState(() {});
  }

  Future<void> _loadIcons() async {
    try {
      final list = await Future.wait<BitmapDescriptor>([
        BitmapDescriptor.asset(
          ImageConfiguration.empty,
          height: 30,
          'assets/bus.webp',
          package: 'icue_sdk',
        ),
        BitmapDescriptor.asset(
          ImageConfiguration.empty,
          height: 40,
          'assets/bus-disable.webp',
          package: 'icue_sdk',
        ),
        BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(45, 45)),
          'assets/school.png',
          package: 'icue_sdk',
        ),
        BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(45, 45)),
          'assets/student-map.png',
          package: 'icue_sdk',
        ),
      ]);
      if (!mounted || _trackingController == null) return;
      _trackingController!.updateIcons(
        bus: list[0],
        busOff: list[1],
        school: list[2],
        student: list[3],
      );
    } catch (e) {
      debugPrint('Error loading map icons: $e');
    }
  }

  void _onCameraTargetChanged() {
    final target = _trackingController?.cameraTargetNotifier.value;
    if (target != null && _autoRecenter) {
      unawaited(_recenterMap(target));
    }
  }

  void _onData() {
    if (!mounted) return;
    _showErrorDialogsIfNeeded();
  }

  void _showErrorDialogsIfNeeded() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final route = ModalRoute.of(context);
        if (route == null || !route.isCurrent || !route.isActive) {
          return;
        }

        if (!_dialogShown &&
            (_vehicleProv.routeEnded || !_vehicleProv.isTrackingAvailable) &&
            _vehicleProv.errorMessage != null &&
            route.isCurrent) {
          _dialogShown = true;
          unawaited(
            showTrackingInfoDialog(context, _vehicleProv.errorMessage ?? ''),
          );
        }
      } catch (e) {
        debugPrint('ModalRoute not ready: $e');
      }
    });
  }

  Future<void> _onMapCreated(GoogleMapController ctl) async {
    if (!mounted) {
      ctl.dispose();
      return;
    }
    _googleMap = ctl;
    _mapReady = true;
    final target = _trackingController?.cameraTargetNotifier.value;
    if (target != null && _autoRecenter) {
      unawaited(_recenterMap(target));
    }
  }

  LatLng _getInitialCameraTarget(User? student, LiveData? liveData) {
    if (liveData != null && liveData.coordinates.length >= 2) {
      return LatLng(liveData.coordinates[0], liveData.coordinates[1]);
    }
    if (student != null &&
        student.schoolPoint != null &&
        student.schoolPoint!.length >= 2) {
      return LatLng(student.schoolPoint![0], student.schoolPoint![1]);
    }
    return const LatLng(17.4065, 78.4772);
  }

  /// Animates the camera to [target].
  ///
  /// [forceZoom] resets the zoom to 18 (used on initial placement and when the
  /// user explicitly taps Recenter). Subsequent auto-recenter calls pass
  /// [forceZoom] = false so the user's zoom level is preserved.
  Future<void> _recenterMap(LatLng target, {bool forceZoom = false}) async {
    if (!mounted || !_mapReady || _googleMap == null || !_autoRecenter) return;
    if (_duringRecenter) {
      _pendingCameraTarget = target;
      return;
    }
    _duringRecenter = true;
    _pendingCameraTarget = null;
    try {
      if (!mounted || _googleMap == null) return;
      final CameraUpdate update;
      if (forceZoom || !_hasDoneInitialCamera) {
        update = CameraUpdate.newLatLngZoom(target, 18);
        _hasDoneInitialCamera = true;
      } else {
        update = CameraUpdate.newLatLng(target);
      }
      await _googleMap!.animateCamera(update);
      if (!mounted) return;
    } on PlatformException catch (e) {
      debugPrint('GoogleMap controller unavailable: $e');
      if (mounted) _mapReady = false;
    } catch (e) {
      debugPrint('Camera animation interrupted: $e');
    } finally {
      if (mounted) {
        _duringRecenter = false;
        if (_pendingCameraTarget != null && _autoRecenter) {
          final nextTarget = _pendingCameraTarget!;
          _pendingCameraTarget = null;
          unawaited(_recenterMap(nextTarget));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _userProvider.user;

    final markersNotifier =
        _trackingController?.markersNotifier ?? _emptyMarkersNotifier;
    final polylinesNotifier =
        _trackingController?.polylinesNotifier ?? _emptyPolylinesNotifier;
    final circlesNotifier =
        _trackingController?.circlesNotifier ?? _emptyCirclesNotifier;
    final isLoadingNotifier =
        _trackingController?.isLoadingNotifier ?? _defaultLoadingNotifier;
    final isOfflineNotifier =
        _trackingController?.isOfflineNotifier ?? _defaultOfflineNotifier;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: const Text('Live Tracking'),
          actions: [
            Selector<VehicleProvider, bool>(
              selector: (context, prov) => prov.isTrackingAvailable,
              builder: (context, isAvailable, child) =>
                  TrackingNotificationsButton(
                student: student,
                isTrackingAvailable: isAvailable,
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _showRecenterButton
            ? FloatingActionButton.extended(
                label: const Text('Recenter'),
                icon: const Icon(Icons.directions_bus_outlined),
                onPressed: () {
                  setState(() {
                    _autoRecenter = true;
                    _showRecenterButton = false;
                  });
                  final pos = _trackingController?.currentBusPosition ??
                      _trackingController?.cameraTargetNotifier.value;
                  if (pos != null) _recenterMap(pos, forceZoom: true);
                },
              )
            : null,
        bottomNavigationBar:
            Selector<VehicleProvider, (LiveData?, bool, VehicleLocation?)>(
          selector: (context, prov) => (
            prov.liveData,
            prov.isTrackingAvailable,
            prov.vehicleLocation,
          ),
          builder: (context, data, child) {
            final (live, isTracking, vehicleLoc) = data;
            return TrackingInfoPanel(
              student: student,
              liveData: live,
              isTrackingAvailable: isTracking,
              vehicleLocation: vehicleLoc,
            );
          },
        ),
        body: PageWrapper(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: (event) {
              if (event.delta.distance > 1.0) {
                _mapGestureResetTimer?.cancel();
                _userInitiatedMapGesture = true;
              }
            },
            onPointerUp: (_) {
              _mapGestureResetTimer?.cancel();
              _mapGestureResetTimer = Timer(
                const Duration(milliseconds: 250),
                () {
                  _userInitiatedMapGesture = false;
                },
              );
            },
            onPointerCancel: (_) {
              _mapGestureResetTimer?.cancel();
              _userInitiatedMapGesture = false;
            },
            child: Stack(
              children: [
                ValueListenableBuilder<Set<Marker>>(
                  valueListenable: markersNotifier,
                  builder: (context, markers, _) {
                    return ValueListenableBuilder<Set<Polyline>>(
                      valueListenable: polylinesNotifier,
                      builder: (context, polylines, _) {
                        return ValueListenableBuilder<Set<Circle>>(
                          valueListenable: circlesNotifier,
                          builder: (context, circles, _) {
                            return GoogleMap(
                              key: const ValueKey('live_tracking_map'),
                              mapToolbarEnabled: false,
                              minMaxZoomPreference: const MinMaxZoomPreference(
                                10,
                                null,
                              ),
                              onMapCreated: _onMapCreated,
                              onCameraMoveStarted: () {
                                if (mounted &&
                                    _userInitiatedMapGesture &&
                                    _autoRecenter &&
                                    !_duringRecenter) {
                                  setState(() {
                                    _autoRecenter = false;
                                    _showRecenterButton = true;
                                  });
                                }
                              },
                              onCameraIdle: () {
                                if (mounted) {
                                  _duringRecenter = false;
                                  _userInitiatedMapGesture = false;
                                }
                              },
                              trafficEnabled: true,
                              polylines: polylines,
                              circles: circles,
                              initialCameraPosition: CameraPosition(
                                target: _getInitialCameraTarget(
                                  student,
                                  _vehicleProv.liveData,
                                ),
                                zoom: 18,
                              ),
                              markers: markers,
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // --- Floating loading indicator ---
                ValueListenableBuilder<bool>(
                  valueListenable: isLoadingNotifier,
                  builder: (context, isLoading, child) {
                    if (!isLoading) return const SizedBox.shrink();
                    return const ConnectingIndicator();
                  },
                ),

                // --- GPS signal lost / reconnected banner ---
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isOfflineNotifier,
                    builder: (context, isOffline, child) {
                      return GpsLostBanner(isOffline: isOffline);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
