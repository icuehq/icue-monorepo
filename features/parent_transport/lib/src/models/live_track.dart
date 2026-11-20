/// The serverless tracking pair: which run of a route is active.
class ActiveRoute {
  const ActiveRoute({required this.routeId, required this.routeTrackId});

  factory ActiveRoute.fromJson(Map<String, dynamic> json) => ActiveRoute(
    routeId: '${json['route_id']}',
    routeTrackId: '${json['route_track_id']}',
  );

  final String routeId;
  final String routeTrackId;
}

/// Latest position on the serverless tracker (`/getlivetrack`).
class LiveTrack {
  const LiveTrack({
    required this.routeTrackId,
    required this.coordinates,
    required this.coordinatesTime,
    required this.serverTime,
  });

  factory LiveTrack.fromJson(Map<String, dynamic> json) => LiveTrack(
    routeTrackId: '${json['RouteTrackId']}',
    coordinates: (json['coordinates'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (e) =>
              (e as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        )
        .toList(),
    coordinatesTime: json['CoordinatesTime'] as String? ?? '',
    serverTime: json['ServerTime'] as String? ?? '',
  );

  final String routeTrackId;
  final List<List<double>> coordinates;
  final String coordinatesTime;
  final String serverTime;
}
