// To parse this JSON data, do
//
//     final announcements = announcementsFromJson(jsonString);

import 'dart:convert';

List<Announcements> announcementsFromJson(String str) =>
    (json.decode(str) as List<dynamic>)
        .map((x) => Announcements.fromJson(x as Map<String, dynamic>))
        .toList();

String announcementsToJson(List<Announcements> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Announcements {
  Announcements({
    // required this.announcementId,
    // required this.id,
    // required this.organizationId,
    // required this.zoneIds,
    // required this.branchIds,
    required this.title,
    required this.description,
    required this.announcementDate,
    required this.announcementTime,
    // required this.expiryDate,
    // required this.image,
    // required this.createdBy,
    // required this.createdDate,
    // required this.isActive,
    // required this.studentIds,
    // required this.mode,
    // required this.details,
  });

  factory Announcements.fromJson(Map<String, dynamic> json) => Announcements(
        title: json['Title']?.toString() ?? '',
        description: json['Description']?.toString() ?? '',
        announcementDate: json['AnnouncementDate']?.toString() ?? '',
        announcementTime: json['AnnouncementTime']?.toString() ?? '',
      );

  final String announcementDate;
  // final String announcementId;
  final String announcementTime;

  // final List<int> branchIds;
  // final String createdBy;
  // final DateTime createdDate;
  final String description;

  // final List<Detail> details;
  // final String expiryDate;
  // final int id;
  // final dynamic image;
  // final bool isActive;
  // final String mode;
  // final int organizationId;
  // final List<int>? studentIds;
  final String title;

  // final List<int> zoneIds;

  Map<String, dynamic> toJson() => {
        // '_id': announcementId,
        // 'Id': id,
        // 'OrganizationId': organizationId,
        // 'ZoneIds': List<dynamic>.from(zoneIds.map((x) => x)),
        // 'BranchIds': List<dynamic>.from(branchIds.map((x) => x)),
        'Title': title,
        'Description': description,
        'AnnouncementDate': announcementDate,
        'AnnouncementTime': announcementTime,
        // 'ExpiryDate': expiryDate,
        // 'Image': image,
        // 'CreatedBy': createdBy,
        // 'CreatedDate': createdDate.toIso8601String(),
        // 'IsActive': isActive,
        // 'StudentIds': studentIds == null
        //     ? null
        //     : List<dynamic>.from(studentIds!.map((x) => x)),
        // 'Mode': mode,
        // 'Details': List<dynamic>.from(details.map((x) => x.toJson())),
      };
}

// class Detail {
//   Detail({
//     required this.routeId,
//     required this.routeNo,
//     required this.pickUpPoints,
//   });

//   factory Detail.fromJson(Map<String, dynamic> json) => Detail(
//         routeId: json['RouteId'],
//         routeNo: json['RouteNo'],
//         pickUpPoints: List<String?>.from(json['PickUpPoints'].map((x) => x)),
//       );

//   final List<String?> pickUpPoints;
//   final int routeId;
//   final String routeNo;

//   Map<String, dynamic> toJson() => {
//         'RouteId': routeId,
//         'RouteNo': routeNo,
//         'PickUpPoints': List<dynamic>.from(pickUpPoints.map((x) => x)),
//       };
// }
