/// The full route path (`/getRouteCoordinate`), each entry [lat, lng].
class RouteCoordinates {
  const RouteCoordinates({required this.path, this.defaultRouteDate});

  factory RouteCoordinates.fromJson(Map<String, dynamic> json) =>
      RouteCoordinates(
        path: (json['OfflineCoordinates'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (e) => (e as List<dynamic>)
                  .map((v) => (v as num).toDouble())
                  .toList(),
            )
            .toList(),
        defaultRouteDate: json['DefaultRouteDate'] as String?,
      );

  final List<List<double>> path;

  /// Version of the route; `/getTraceDate` says whether it changed.
  final String? defaultRouteDate;
}
