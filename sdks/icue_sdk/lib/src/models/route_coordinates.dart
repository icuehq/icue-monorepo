// To parse this JSON data, do
//
//     final routeCoordinates = routeCoordinatesFromJson(jsonString);

import 'dart:convert';

RouteCoordinates routeCoordinatesFromJson(String str) =>
    RouteCoordinates.fromJson(json.decode(str) as Map<String, dynamic>);

String routeCoordinatesToJson(RouteCoordinates data) =>
    json.encode(data.toJson());

class RouteCoordinates {
  RouteCoordinates({
    required this.err,
    required this.offlineCoordinates,
    this.defaultRouteDate,
  });

  factory RouteCoordinates.fromJson(Map<String, dynamic> json) =>
      RouteCoordinates(
        err: (json['err'] as bool?) ?? false,
        offlineCoordinates: _parseCoordinatesList(json['OfflineCoordinates']),
        defaultRouteDate: json['DefaultRouteDate'] as String?,
      );

  final String? defaultRouteDate;
  final bool err;
  final List<List<double>> offlineCoordinates;

  Map<String, dynamic> toJson() => {
        'err': err,
        'OfflineCoordinates': List<dynamic>.from(
          offlineCoordinates.map((x) => List<dynamic>.from(x.map((x) => x))),
        ),
        'DefaultRouteDate': defaultRouteDate,
      };

  static List<List<double>> _parseCoordinatesList(dynamic jsonList) {
    if (jsonList is! List) return [];
    final result = <List<double>>[];
    for (final entry in jsonList) {
      if (entry is List) {
        final pair = <double>[];
        for (final item in entry) {
          if (item is num) {
            pair.add(item.toDouble());
          } else if (item is String) {
            final parsed = double.tryParse(item);
            if (parsed != null) pair.add(parsed);
          }
        }
        if (pair.length >= 2 &&
            pair[0] >= -90 &&
            pair[0] <= 90 &&
            pair[1] >= -180 &&
            pair[1] <= 180) {
          result.add(pair);
        }
      }
    }
    return result;
  }
}
