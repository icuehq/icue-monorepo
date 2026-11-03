import 'package:flutter/foundation.dart';

@immutable
class CreateComplaintRequest {
  const CreateComplaintRequest({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.categoryId,
    required this.description,
    this.newCategoryName,
    this.photoBytes,
    this.photoName,
  });

  final int vehicleId;
  final String vehicleNumber;
  final int categoryId;
  final String description;
  final String? newCategoryName;
  final List<int>? photoBytes;
  final String? photoName;
}

@immutable
class UpdateComplaintRequest {
  const UpdateComplaintRequest({
    required this.id,
    required this.status, // e.g. "In-Progress", "Resolved", "Closed"
    required this.action,
    this.description,
    this.photoBytes,
    this.photoName,
  });

  final int id;
  final String status;
  final String action;
  final String? description;
  final List<int>? photoBytes;
  final String? photoName;
}
