import 'package:routes/src/models/routes.dart';

class ChangeRouteRequest {
  const ChangeRouteRequest({
    required this.mode,
    required this.studentId,
    required this.classId,
    required this.sections,
    this.existingRouteId,
    this.route,
    this.point,
  });

  final RouteMode mode;
  final int studentId;
  final int classId;
  final List<String> sections;
  final int? existingRouteId;
  final int? route;
  final String? point;

  Map<String, dynamic> toJson() => {
        'IsInTransport': existingRouteId != null ? 'yes' : 'no',
        'ChangeMode': mode.label,
        'StudentId': studentId,
        'ClassId': classId,
        'Sections': sections,
        ...(mode == RouteMode.pickup
            ? {
                if (existingRouteId != null) 'PickupRouteId': existingRouteId,
                'TargetPickupRoute': route,
                'TargetPickPoint': point,
              }
            : {
                if (existingRouteId != null) 'DropRouteId': existingRouteId,
                'TargetDropRoute': route,
                'TargetDropPoint': point,
              }),
      };
}

class ChangeBothRoutesRequest {
  const ChangeBothRoutesRequest({
    required this.studentId,
    required this.classId,
    required this.sections,
    this.existingPickupRouteId,
    this.existingDropRouteId,
    this.existingPickupPoint,
    required this.pickupRoute,
    required this.pickupPoint,
    required this.dropRoute,
    required this.dropPoint,
  });

  final int studentId;
  final int classId;
  final List<String> sections;
  final int? existingPickupRouteId;
  final int? existingDropRouteId;
  final String? existingPickupPoint;
  final int pickupRoute;
  final String pickupPoint;
  final int dropRoute;
  final String dropPoint;

  Map<String, dynamic> toJson() => {
        'IsInTransport': existingPickupRouteId != null ? 'yes' : 'no',
        'StudentId': studentId,
        'ClassId': classId,
        'Sections': sections,
        if (existingPickupRouteId != null)
          'PickupRouteId': existingPickupRouteId,
        if (existingDropRouteId != null) 'DropRouteId': existingDropRouteId,
        if (existingPickupPoint != null)
          'ExistingPickPoint': existingPickupPoint,
        'TargetPickupRoute': pickupRoute,
        'TargetPickPoint': pickupPoint,
        'TargetDropRoute': dropRoute,
        'TargetDropPoint': dropPoint,
      };
}

class UpdateRouteTimeRequest {
  const UpdateRouteTimeRequest({
    required this.time,
    required this.mode,
    required this.changeMode,
    this.selectedRouteIds = const <int>[],
  });

  final String time;
  final RouteMode mode;
  final String changeMode; // 'ALL' or 'CUSTOM'
  final List<int> selectedRouteIds;

  Map<String, dynamic> toJson() => {
        'RouteStartTime': time,
        'Mode': mode.label,
        'ChangeMode': changeMode,
        if (changeMode != 'ALL') 'RouteIds': selectedRouteIds,
      };
}
