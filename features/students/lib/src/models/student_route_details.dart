class StudentRouteDetails {
  const StudentRouteDetails({
    required this.showPointTime,
    required this.routes,
  });

  factory StudentRouteDetails.fromJson(Map<String, dynamic> json) =>
      StudentRouteDetails(
        showPointTime: json['ShowRtPntTime'] as bool? ?? false,
        routes: (json['Routes'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => StudentRoute.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final bool showPointTime;
  final List<StudentRoute> routes;
}

class StudentRoute {
  const StudentRoute({
    required this.id,
    required this.mode,
    this.routeNumber,
    this.pointName,
    this.pointTime,
  });

  factory StudentRoute.fromJson(Map<String, dynamic> json) => StudentRoute(
    id: (json['Id'] as num).toInt(),
    mode: json['Mode'] as String? ?? '',
    routeNumber: json['RtNo'] as String?,
    pointName: json['PntName'] as String?,
    pointTime: json['PntTime'] as String?,
  );

  final int id;
  final String mode;
  final String? routeNumber;
  final String? pointName;
  final String? pointTime;
}
