import 'dart:async';

import 'package:auth/auth.dart';
import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/src/models/live_data.dart';

const _assets = 'packages/parent_transport/assets';
const _fallbackCenter = LatLng(17.4065, 78.4772);

/// Google map with the route, the stops and a bus that glides between fixes.
/// Follows the bus until the user moves the map; a button then re-centres.
class LiveMap extends StatefulWidget {
  const LiveMap({required this.data, required this.student, super.key});

  final LiveData? data;
  final ParentStudent student;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  final _snapper = PolylineSnapper();
  final _staticMarkers = <MarkerId, Marker>{};
  late final AnimationController _glide = AnimationController(vsync: this)
    ..addListener(_onGlideTick);

  GoogleMapController? _map;
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _busOffIcon;
  BitmapDescriptor? _schoolIcon;
  BitmapDescriptor? _studentIcon;

  LatLng? _from;
  LatLng? _to;
  LatLng? _busPosition;
  double _fromRotation = 0;
  double _toRotation = 0;
  double _rotation = 0;
  bool _busOnline = true;

  bool _following = true;
  bool _userGesture = false;
  bool _recentering = false;
  Timer? _gestureReset;

  @override
  void initState() {
    super.initState();
    unawaited(_loadIcons());
  }

  @override
  void didUpdateWidget(LiveMap old) {
    super.didUpdateWidget(old);
    if (widget.data != old.data) _onData(widget.data);
  }

  @override
  void dispose() {
    _gestureReset?.cancel();
    _glide.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<BitmapDescriptor> _icon(String file, {double? height, Size? size}) =>
      BitmapDescriptor.asset(
        size == null
            ? ImageConfiguration.empty
            : ImageConfiguration(size: size),
        '$_assets/$file',
        height: height,
      );

  Future<void> _loadIcons() async {
    final icons = await Future.wait([
      _icon('bus.webp', height: 30),
      _icon('bus-disable.webp', height: 40),
      _icon('school.png', size: const Size(45, 45)),
      _icon('student-map.png', size: const Size(45, 45)),
    ]);
    if (!mounted) return;
    setState(() {
      _busIcon = icons[0];
      _busOffIcon = icons[1];
      _schoolIcon = icons[2];
      _studentIcon = icons[3];
    });
    _onData(widget.data);
  }

  void _onData(LiveData? data) {
    if (data == null || _busIcon == null || !mounted) return;
    _buildStaticMarkers(data);
    _busOnline = data.hasNetwork;
    final fix = data.busPosition;
    if (fix != null) _moveBus(_snapper.snap(fix, data.polyline));
    setState(() {});
  }

  void _buildStaticMarkers(LiveData data) {
    _staticMarkers.clear();
    final school = widget.student.schoolPoint;
    if (school != null && school.length >= 2) {
      _staticMarkers[const MarkerId('school')] = Marker(
        markerId: const MarkerId('school'),
        position: LatLng(school.first, school.last),
        icon: _schoolIcon!,
        infoWindow: InfoWindow(
          title: widget.student.schoolName,
          snippet: ParentLocalizations.of(context).school,
        ),
      );
    }
    final stop = data.studentStop;
    if (stop != null && stop.coordinates.length >= 2) {
      _staticMarkers[const MarkerId('student')] = Marker(
        markerId: const MarkerId('student'),
        position: LatLng(stop.coordinates.first, stop.coordinates.last),
        icon: _studentIcon!,
        infoWindow: InfoWindow(
          title: stop.pickPoint,
          snippet: ParentLocalizations.of(context).yourPoint,
        ),
      );
    }
    for (final stop in data.stops) {
      if (stop.coordinates.length < 2) continue;
      final id = MarkerId(stop.pickPoint ?? stop.coordinates.toString());
      _staticMarkers.putIfAbsent(
        id,
        () => Marker(
          markerId: id,
          position: LatLng(stop.coordinates.first, stop.coordinates.last),
          infoWindow: InfoWindow(title: stop.pickPoint, snippet: ''),
          onTap: () => _map?.showMarkerInfoWindow(id),
        ),
      );
    }
  }

  void _moveBus(LatLng target) {
    final current = _busPosition;
    if (current == null) {
      _busPosition = _from = _to = target;
      _rotation = _fromRotation = _toRotation = busRotation(target, target);
      return;
    }
    final distance = distanceMeters(current, target);
    _fromRotation = _rotation;
    _toRotation = busRotation(current, target);
    _from = current;
    _to = target;
    if (_following && distance > 5) unawaited(_recenter(target));
    if (distance > 2) {
      _glide
        ..duration = Duration(
          milliseconds: (300 + (distance * 2).clamp(0, 700)).toInt(),
        )
        ..forward(from: 0);
    } else {
      _busPosition = target;
      _rotation = _toRotation;
    }
  }

  void _onGlideTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null || !mounted) return;
    setState(() {
      _busPosition = interpolateLatLng(
        from,
        to,
        Curves.easeOutCubic.transform(_glide.value),
      );
      _rotation = interpolateRotation(_fromRotation, _toRotation, _glide.value);
    });
  }

  Future<void> _recenter(LatLng target) async {
    final map = _map;
    if (map == null || _recentering || !target.latitude.isFinite) return;
    _recentering = true;
    try {
      await map.animateCamera(CameraUpdate.newLatLngZoom(target, 18));
    } on Object {
      // The controller can be disposed mid-animation when the page closes.
    } finally {
      _recentering = false;
    }
  }

  Set<Marker> get _markers => {
    ..._staticMarkers.values,
    if (_busPosition != null && _busIcon != null)
      Marker(
        markerId: const MarkerId('bus'),
        position: _busPosition!,
        icon: _busOnline ? _busIcon! : (_busOffIcon ?? _busIcon!),
        anchor: const Offset(0.5, 0.5),
        rotation: _rotation,
      ),
  };

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _gestureReset?.cancel();
            _userGesture = true;
          },
          onPointerUp: (_) {
            _gestureReset?.cancel();
            _gestureReset = Timer(
              const Duration(milliseconds: 250),
              () => _userGesture = false,
            );
          },
          onPointerCancel: (_) {
            _gestureReset?.cancel();
            _userGesture = false;
          },
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: data?.busPosition ?? _fallbackCenter,
              zoom: 18,
            ),
            trafficEnabled: true,
            markers: _markers,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: data?.polyline ?? const <LatLng>[],
                width: 3,
                color: Colors.blue,
              ),
            },
            onMapCreated: (controller) {
              _map = controller;
              _onData(widget.data);
            },
            onCameraMoveStarted: () {
              if (_userGesture && _following) {
                setState(() => _following = false);
              }
            },
            onCameraIdle: () {
              _recentering = false;
              _userGesture = false;
            },
          ),
        ),
        if (!_following)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.directions_bus_outlined),
                label: Text(ParentLocalizations.of(context).recenter),
                onPressed: () {
                  setState(() => _following = true);
                  final bus = _busPosition;
                  if (bus != null) unawaited(_recenter(bus));
                },
              ),
            ),
          ),
      ],
    );
  }
}
