# bus_tracking_core

Shared by `features/parent_transport` and `sdks/icue_sdk`:

- Geometry: `distanceMeters`, `bearingDegrees`, `busRotation`, `interpolateRotation`, `interpolateLatLng`, `extrapolate`, `PolylineSnapper`.
- `fixAgeSeconds`: age of the bus's last GPS fix (999 when unreadable).
- `TrackingMessageDialog`: the "route not started / completed" dialog with a 5 s countdown. The caller passes `onClose` and owns navigation.
- `TrackingInfoCard`: pickup point, route, ETA and call-driver card (plain widgets, English text).
