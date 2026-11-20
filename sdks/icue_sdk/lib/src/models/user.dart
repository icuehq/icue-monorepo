// To parse this JSON data, do
//
//     final user = userFromJson(jsonString);

import 'dart:convert';

User userFromJson(String str) =>
    User.fromJson(json.decode(str) as Map<String, dynamic>);

String userToJson(User data) => json.encode(data.toJson());

class User {
  User({
    required this.organizationId,
    required this.branchId,
    required this.zoneId,
    required this.id,
    required this.name,
    required this.rollNo,
    required this.admissionNumber,
    required this.classId,
    required this.standard,
    required this.section,
    required this.gender,
    required this.parentName,
    this.primaryContact,
    this.secondaryContact,
    required this.pickPoint,
    required this.pickArea,
    required this.dropArea,
    required this.dropPoint,
    required this.isMessOpted,
    required this.isTransportOpted,
    this.area,
    this.showRoutePanel,
    this.showNotification,
    this.showContactNo,
    this.showEta,
    this.etainfo,
    this.socketserver,
    this.locSocketServer,
    this.schoolName,
    this.schoolPoint,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        organizationId: (json['OrganizationId'] as int?) ?? 0,
        branchId: (json['BranchId'] as int?) ?? 0,
        zoneId: (json['ZoneId'] as int?) ?? 0,
        id: (json['Id'] as int?) ?? 0,
        name: json['Name']?.toString() ?? '',
        rollNo: json['RollNo']?.toString() ?? '',
        admissionNumber: json['AdmissionNumber']?.toString() ?? '',
        classId: (json['ClassId'] as int?) ?? 0,
        standard: json['Standard']?.toString() ?? '',
        section: json['Section']?.toString() ?? '',
        gender: json['Gender']?.toString() ?? '',
        parentName: json['ParentName']?.toString() ?? '',
        primaryContact: json['PrimaryContact'] as int?,
        secondaryContact: json['SecondaryContact'] as int?,
        pickPoint: json['PickPoint'] as String?,
        pickArea: json['PickArea'] as String?,
        dropArea: json['DropArea'] as String?,
        dropPoint: json['DropPoint'] as String?,
        isMessOpted: json['IsMessOpted'] as bool?,
        isTransportOpted: json['IsTransportOpted'] as bool?,
        area: json['Area'],
        showRoutePanel: json['ShowRoutePanel'] as bool?,
        showNotification: json['ShowNotification'] as bool?,
        showContactNo: json['ShowContactNo'] as bool?,
        showEta: json['ShowETA'] as bool?,
        etainfo: json['ETAINFO'] as String?,
        socketserver: json['socketserver'] as String?,
        locSocketServer: json['locSocketServer'] as String?,
        schoolName: json['SchoolName'] as String?,
        schoolPoint: _parseCoordinateList(json['SchoolPoint']),
        token: json['Token'] as String?,
      );

  final String admissionNumber;
  final dynamic area;
  final int branchId;
  final int classId;
  final String? dropArea;
  final String? dropPoint;
  final String? etainfo;
  final String gender;
  final int id;
  final bool? isMessOpted;
  final bool? isTransportOpted;
  final String? locSocketServer;
  final String name;
  final int organizationId;
  final String parentName;
  final String? pickArea;
  final String? pickPoint;
  final int? primaryContact;
  final String rollNo;
  final String? schoolName;
  final List<double>? schoolPoint;
  final int? secondaryContact;
  final String section;
  final bool? showContactNo;
  final bool? showEta;
  final bool? showNotification;
  final bool? showRoutePanel;
  final String? socketserver;
  final String standard;
  final String? token;
  final int zoneId;

  Map<String, dynamic> toJson() => {
        'OrganizationId': organizationId,
        'BranchId': branchId,
        'ZoneId': zoneId,
        'Id': id,
        'Name': name,
        'RollNo': rollNo,
        'AdmissionNumber': admissionNumber,
        'ClassId': classId,
        'Standard': standard,
        'Section': section,
        'Gender': gender,
        'ParentName': parentName,
        'PrimaryContact': primaryContact,
        'SecondaryContact': secondaryContact,
        'PickPoint': pickPoint,
        'PickArea': pickArea,
        'DropArea': dropArea,
        'DropPoint': dropPoint,
        'IsMessOpted': isMessOpted,
        'IsTransportOpted': isTransportOpted,
        'Area': area,
        'ShowRoutePanel': showRoutePanel,
        'ShowNotification': showNotification,
        'ShowContactNo': showContactNo,
        'ShowETA': showEta,
        'ETAINFO': etainfo,
        'socketserver': socketserver,
        'locSocketServer': locSocketServer,
        'SchoolName': schoolName,
        'SchoolPoint': schoolPoint == null
            ? <dynamic>[]
            : List<dynamic>.from(schoolPoint!.map((x) => x)),
        'Token': token,
      };

  static List<double>? _parseCoordinateList(dynamic jsonList) {
    if (jsonList is! List) return null;
    final coords = <double>[];
    for (final item in jsonList) {
      if (item is num) {
        coords.add(item.toDouble());
      } else if (item is String) {
        final parsed = double.tryParse(item);
        if (parsed != null) coords.add(parsed);
      }
    }
    return coords.length >= 2 ? coords : null;
  }
}
