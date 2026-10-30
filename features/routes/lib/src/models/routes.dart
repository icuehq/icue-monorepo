enum RouteMode {
  pickup('Pickup'),
  drop('Drop');

  const RouteMode(this.label);
  final String label;

  static RouteMode fromString(String? val) {
    if (val?.toLowerCase() == 'pickup') return RouteMode.pickup;
    return RouteMode.drop;
  }
}

class RoutePoint {
  const RoutePoint({required this.name, this.studentIds = const <int>[]});

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
    name: json['Name'] as String? ?? '',
    studentIds: json['StudentIds'] is List
        ? (json['StudentIds'] as List)
              .map((x) => int.tryParse(x.toString()) ?? 0)
              .toList()
        : const <int>[],
  );

  final String name;
  final List<int> studentIds;

  Map<String, dynamic> toJson() => {'Name': name, 'StudentIds': studentIds};
}

class Routee {
  const Routee({
    required this.id,
    required this.routeNo,
    required this.mode,
    this.points = const <RoutePoint>[],
    this.vehicleNumber,
    this.routeStartTime,
  });

  factory Routee.fromJson(Map<String, dynamic> json) => Routee(
    id: json['Id'] as int? ?? 0,
    routeNo: json['RouteNo'] as String? ?? '',
    mode: RouteMode.fromString(json['Mode'] as String?),
    vehicleNumber: json['VehicleNumber'] as String?,
    routeStartTime: json['RouteStartTime'] as String?,
    points: json['Points'] is List
        ? (json['Points'] as List)
              .whereType<Map<String, dynamic>>()
              .map(RoutePoint.fromJson)
              .toList()
        : const <RoutePoint>[],
  );

  final int id;
  final String routeNo;
  final RouteMode mode;
  final List<RoutePoint> points;
  final String? vehicleNumber;
  final String? routeStartTime;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'RouteNo': routeNo,
    'Mode': mode.label,
    'VehicleNumber': vehicleNumber,
    'RouteStartTime': routeStartTime,
    'Points': points.map((x) => x.toJson()).toList(),
  };
}

class RoutesResponse {
  const RoutesResponse({
    this.err = false,
    this.message = '',
    this.routes = const <Routee>[],
  });

  factory RoutesResponse.fromJson(Map<String, dynamic> json) => RoutesResponse(
    err: json['err'] as bool? ?? false,
    message: json['message'] as String? ?? '',
    routes: json['Route'] is List
        ? (json['Route'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Routee.fromJson)
              .toList()
        : const <Routee>[],
  );

  final bool err;
  final String message;
  final List<Routee> routes;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'Route': routes.map((x) => x.toJson()).toList(),
  };
}
