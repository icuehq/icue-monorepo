import 'package:flutter/foundation.dart';

/// An image attached to a complaint.
@immutable
class ComplaintPhoto {
  const ComplaintPhoto({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

@immutable
class CreateComplaintRequest {
  const CreateComplaintRequest({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.categoryId,
    required this.description,
    this.newCategoryName,
    this.photos = const <ComplaintPhoto>[],
  });

  final int vehicleId;
  final String vehicleNumber;
  final int categoryId;
  final String description;
  final String? newCategoryName;
  final List<ComplaintPhoto> photos;
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
