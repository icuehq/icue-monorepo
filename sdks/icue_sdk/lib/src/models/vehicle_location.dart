import 'dart:convert';

/// Utilities for serializing and deserializing [VehicleLocation].
VehicleLocation vehicleLocationFromJson(String str) =>
    VehicleLocation.fromJson(json.decode(str) as Map<String, dynamic>);

String vehicleLocationToJson(VehicleLocation data) =>
    json.encode(data.toJson());

/// Snapshot of a vehicle's live location and related telemetry.
class VehicleLocation {
  VehicleLocation({
    required this.routeDetailsId,
    required this.routeNo,
    required this.coordinates,
    required this.coordinatesTime,
    required this.coordinatesSpeed,
    required this.serverTime,
    required this.routeTrackId,
    this.driverData,
    this.routeCoOrdinates,
    this.mode,
    required this.enableLocationPush,
    required this.enableLocPush,
    required this.msgAvailable,
    required this.msgCount,
    required this.isEtaPush,
    required this.isEtaFetch,
    this.etaValue,
    this.deviation,
    this.etahide,
    this.ast,
    this.totalDist,
    this.rd,
    this.rtIndex,
  });

  factory VehicleLocation.fromJson(Map<String, dynamic> json) =>
      VehicleLocation(
        routeDetailsId: json['RouteDetailsId'] as int,
        routeNo: json['RouteNo'] as String,
        coordinates: _parseCoordinatesList(json['coordinates']),
        coordinatesTime: json['CoordinatesTime'] as String,
        coordinatesSpeed: (json['CoordinatesSpeed'] as num?)?.toDouble() ?? 0.0,
        serverTime: json['ServerTime'] as String,
        routeTrackId: json['RouteTrackId'] as int,
        driverData: json['DriverData'] == null
            ? null
            : DriverData.fromJson(json['DriverData'] as Map<String, dynamic>),
        routeCoOrdinates: json['routeCoOrdinates'] == null
            ? null
            : (json['routeCoOrdinates'] as List<dynamic>)
                .map(
                  (x) => RouteCoOrdinate.fromJson(x as Map<String, dynamic>),
                )
                .toList(),
        mode: json['Mode'] as String?,
        enableLocationPush: json['enableLocationPush'] as bool,
        enableLocPush: json['enableLocPush'] as bool,
        msgAvailable: json['MsgAvailable'] as bool,
        msgCount: json['MsgCount'] as int,
        isEtaPush: json['IsETAPush'] as bool,
        isEtaFetch: json['IsETAFetch'] as bool,
        etaValue: json['ETAValue'] as String?,
        deviation: json['Deviation'] as bool?,
        etahide: json['ETAHIDE'] as bool?,
        ast: json['AST'] as String?,
        totalDist: json['TotalDist'] as String?,
        rd: json['RD'] == null
            ? null
            : (json['RD'] as List<dynamic>)
                .map((x) => Rd.fromJson(x as Map<String, dynamic>))
                .toList(),
        rtIndex: json['RTIndex'] as int?,
      );

  final String? ast;
  final List<List<double>> coordinates;
  final num coordinatesSpeed;
  final String coordinatesTime;
  final bool? deviation;
  final DriverData? driverData;
  final bool enableLocPush;
  final bool enableLocationPush;
  final String? etaValue;
  final bool? etahide;
  final bool isEtaFetch;
  final bool isEtaPush;
  final String? mode;
  final bool msgAvailable;
  final int msgCount;
  final List<Rd>? rd;
  final List<RouteCoOrdinate>? routeCoOrdinates;
  final int routeDetailsId;
  final String routeNo;
  final int routeTrackId;
  final int? rtIndex;
  final String serverTime;
  final String? totalDist;

  Map<String, dynamic> toJson() => {
        'RouteDetailsId': routeDetailsId,
        'RouteNo': routeNo,
        'coordinates': List<dynamic>.from(
          coordinates.map((x) => List<dynamic>.from(x.map((x) => x))),
        ),
        'CoordinatesTime': coordinatesTime,
        'CoordinatesSpeed': coordinatesSpeed,
        'ServerTime': serverTime,
        'RouteTrackId': routeTrackId,
        'DriverData': driverData?.toJson(),
        'routeCoOrdinates': routeCoOrdinates == null
            ? null
            : List<dynamic>.from(routeCoOrdinates!.map((x) => x.toJson())),
        'Mode': mode,
        'enableLocationPush': enableLocationPush,
        'enableLocPush': enableLocPush,
        'MsgAvailable': msgAvailable,
        'MsgCount': msgCount,
        'IsETAPush': isEtaPush,
        'IsETAFetch': isEtaFetch,
        'ETAValue': etaValue,
        'Deviation': deviation,
        'ETAHIDE': etahide,
        'AST': ast,
        'TotalDist': totalDist,
        'RD':
            rd == null ? null : List<dynamic>.from(rd!.map((x) => x.toJson())),
        'RTIndex': rtIndex,
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

/// Driver metadata associated with the current vehicle.
class DriverData {
  DriverData({
    required this.name,
    required this.mobile,
    required this.vehicleNumber,
  });

  factory DriverData.fromJson(Map<String, dynamic> json) => DriverData(
        name: json['Name'] as String,
        mobile: json['Mobile'] as int,
        vehicleNumber: json['VehicleNumber'] as String,
      );

  int mobile;
  final String name;
  final String vehicleNumber;

  Map<String, dynamic> toJson() => {
        'Name': name,
        'Mobile': mobile,
        'VehicleNumber': vehicleNumber,
      };
}

/// Route deviation/time markers.
class Rd {
  Rd({this.rdTime, this.rdStartIndex});

  factory Rd.fromJson(Map<String, dynamic> json) => Rd(
        rdTime: json['RDTime'] as String?,
        rdStartIndex: json['RDStartIndex'] as String?,
      );

  final String? rdStartIndex;
  final String? rdTime;

  Map<String, dynamic> toJson() => {
        'RDTime': rdTime,
        'RDStartIndex': rdStartIndex,
      };
}

/// Named coordinate along the route path.
class RouteCoOrdinate {
  RouteCoOrdinate({this.pickPoint, required this.coordinates, this.landMark});

  factory RouteCoOrdinate.fromJson(Map<String, dynamic> json) =>
      RouteCoOrdinate(
        pickPoint: json['PickPoint'] as String?,
        coordinates: _parseSinglePoint(json['coordinates']),
        landMark: json['LandMark'] as String?,
      );

  final List<double> coordinates;
  final String? landMark;
  final String? pickPoint;

  Map<String, dynamic> toJson() => {
        'PickPoint': pickPoint,
        'coordinates': List<dynamic>.from(coordinates.map((x) => x)),
        'LandMark': landMark,
      };

  static List<double> _parseSinglePoint(dynamic jsonList) {
    if (jsonList is! List) return [];
    final pair = <double>[];
    for (final item in jsonList) {
      if (item is num) {
        pair.add(item.toDouble());
      } else if (item is String) {
        final parsed = double.tryParse(item);
        if (parsed != null) pair.add(parsed);
      }
    }
    return (pair.length >= 2 &&
            pair[0] >= -90 &&
            pair[0] <= 90 &&
            pair[1] >= -180 &&
            pair[1] <= 180)
        ? pair
        : [];
  }
}
