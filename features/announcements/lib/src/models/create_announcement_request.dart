import 'package:flutter/foundation.dart';

@immutable
class CreateAnnouncementRequest {
  const CreateAnnouncementRequest({
    required this.title,
    required this.description,
    required this.mode,
    required this.routes,
    this.points,
    this.studentIds,
  });

  final String title;
  final String description;
  final String mode;
  final List<int> routes;
  final List<String>? points;
  final List<int>? studentIds;

  Map<String, dynamic> toJson() => {
    'Title': title,
    'Description': description,
    'Mode': mode,
    'Routes': routes,
    'PickUpPoints': ?points,
    'StudentIds': ?studentIds,
  };
}
