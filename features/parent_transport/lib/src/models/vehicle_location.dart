/// A stop of the student's route (`routeCoOrdinates`), `coordinates` = [lat, lng].
class RouteStop {
  const RouteStop({required this.coordinates, this.pickPoint, this.landMark});

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    pickPoint: json['PickPoint'] as String?,
    coordinates: _doubles(json['coordinates']),
    landMark: json['LandMark'] as String?,
  );

  final String? pickPoint;
  final List<double> coordinates;
  final String? landMark;
}

class DriverData {
  const DriverData({
    required this.name,
    required this.mobile,
    required this.vehicleNumber,
  });

  factory DriverData.fromJson(Map<String, dynamic> json) => DriverData(
    name: json['Name'] as String? ?? '',
    mobile: '${json['Mobile']}',
    vehicleNumber: json['VehicleNumber'] as String? ?? '',
  );

  final String name;
  final String mobile;
  final String vehicleNumber;
}

/// Live position of the student's bus (`/getVehicleLocation`).
/// `coordinates` holds recent [lat, lng] fixes, newest first.
class VehicleLocation {
  const VehicleLocation({
    required this.routeDetailsId,
    required this.routeNo,
    required this.routeTrackId,
    required this.coordinates,
    required this.coordinatesTime,
    required this.serverTime,
    required this.msgAvailable,
    this.driver,
    this.stops,
    this.mode,
    this.etaValue,
  });

  factory VehicleLocation.fromJson(Map<String, dynamic> json) =>
      VehicleLocation(
        routeDetailsId: (json['RouteDetailsId'] as num).toInt(),
        routeNo: json['RouteNo'] as String? ?? '',
        routeTrackId: (json['RouteTrackId'] as num?)?.toInt() ?? 0,
        coordinates: (json['coordinates'] as List<dynamic>? ?? <dynamic>[])
            .map(_doubles)
            .toList(),
        coordinatesTime: json['CoordinatesTime'] as String? ?? '',
        serverTime: json['ServerTime'] as String? ?? '',
        msgAvailable: json['MsgAvailable'] as bool? ?? false,
        driver: json['DriverData'] == null
            ? null
            : DriverData.fromJson(json['DriverData'] as Map<String, dynamic>),
        stops: (json['routeCoOrdinates'] as List<dynamic>?)
            ?.map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        mode: json['Mode'] as String?,
        etaValue: json['ETAValue'] as String?,
      );

  final int routeDetailsId;
  final String routeNo;
  final int routeTrackId;
  final List<List<double>> coordinates;
  final String coordinatesTime;
  final String serverTime;
  final bool msgAvailable;
  final DriverData? driver;

  /// Only sent on the first request (before the app has the route cached).
  final List<RouteStop>? stops;

  /// `Pickup` or `Drop`; picks which student stop to show.
  final String? mode;
  final String? etaValue;
}

List<double> _doubles(dynamic value) => (value as List<dynamic>? ?? <dynamic>[])
    .map((e) => (e as num).toDouble())
    .toList();
