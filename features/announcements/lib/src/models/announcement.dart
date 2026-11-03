import 'package:flutter/foundation.dart';

@immutable
class Announcement {
  const Announcement({
    required this.announcementId,
    required this.id,
    this.organizationId = 0,
    this.zoneIds = const <int>[],
    this.branchIds = const <int>[],
    this.studentIds = const <dynamic>[],
    required this.title,
    required this.description,
    this.announcementDate = '',
    this.announcementTime = '',
    this.expiryDate,
    this.image,
    this.createdBy = '',
    this.createdDate,
    this.isActive = true,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['_id'] as String? ?? '',
      id: json['Id'] as int? ?? 0,
      organizationId: json['OrganizationId'] as int? ?? 0,
      zoneIds:
          (json['ZoneIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      branchIds:
          (json['BranchIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      studentIds:
          (json['StudentIds'] as List<dynamic>?)
              ?.where((e) => e != null)
              .toList() ??
          const <dynamic>[],
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      announcementDate: json['AnnouncementDate'] as String? ?? '',
      announcementTime: json['AnnouncementTime'] as String? ?? '',
      expiryDate: json['ExpiryDate'] as String?,
      image: json['Image'],
      createdBy: json['CreatedBy'] as String? ?? '',
      createdDate: json['CreatedDate'] != null
          ? DateTime.tryParse(json['CreatedDate'].toString())
          : null,
      isActive: json['IsActive'] as bool? ?? true,
    );
  }

  final String announcementId;
  final int id;
  final int organizationId;
  final List<int> zoneIds;
  final List<int> branchIds;
  final List<dynamic> studentIds;
  final String title;
  final String description;
  final String announcementDate;
  final String announcementTime;
  final String? expiryDate;
  final dynamic image;
  final String createdBy;
  final DateTime? createdDate;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    '_id': announcementId,
    'Id': id,
    'OrganizationId': organizationId,
    'ZoneIds': zoneIds,
    'BranchIds': branchIds,
    'StudentIds': studentIds,
    'Title': title,
    'Description': description,
    'AnnouncementDate': announcementDate,
    'AnnouncementTime': announcementTime,
    'ExpiryDate': ?expiryDate,
    'Image': ?image,
    'CreatedBy': createdBy,
    'CreatedDate': ?createdDate?.toIso8601String(),
    'IsActive': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Announcement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          announcementId == other.announcementId;

  @override
  int get hashCode => id.hashCode ^ announcementId.hashCode;
}
