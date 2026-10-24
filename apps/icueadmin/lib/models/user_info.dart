// To parse this JSON data, do
//
//     final userInfo = userInfoFromJson(jsonString);

// ignore_for_file: unnecessary_lambdas

import 'dart:convert';

import 'package:hive/hive.dart';

part 'user_info.g.dart';

UserInfo userInfoFromJson(String str) => UserInfo.fromJson(json.decode(str));

String userInfoToJson(UserInfo data) => json.encode(data.toJson());

@HiveType(typeId: 2)
class UserInfo {
  UserInfo({
    required this.id,
    required this.name,
    required this.userName,
    required this.organizationId,
    required this.zoneId,
    required this.branchId,
    required this.roles,
    required this.classes,
    required this.mobile,
    required this.sesid,
    required this.isCorporate,
    required this.isLogistics,
    required this.orgType,
    required this.typeOfBusiness,
    required this.loginType,
    required this.wardId,
    this.enableVirtualClassRoom,
    this.enableVroomMeeting,
    this.enableVroomItAdminApproval,
    this.enableVoice,
    this.isWebRtcEnabled,
    this.isTextChatEnabled,
    this.isAudioBridgeEnabled,
    required this.token,
    required this.isFirstLogin,
    this.schoolName,
    required this.schoolShortName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['Id'],
    name: json['Name'],
    userName: json['UserName'],
    organizationId: json['OrganizationId'],
    zoneId: json['ZoneId'],
    branchId: json['BranchId'],
    roles: List<Role>.from(json['Roles'].map((x) => Role.fromJson(x))),
    classes: json['Classes'] == null
        ? []
        : json['Classes'].runtimeType == String
        ? json['Classes']
        : List<UserClass>.from(
            json['Classes'].map((x) => UserClass.fromJson(x)),
          ),
    mobile: json['Mobile'],
    sesid: json['Sesid'],
    isCorporate: json['IsCorporate'],
    isLogistics: json['IsLogistics'],
    orgType: json['OrgType'],
    typeOfBusiness: json['TypeOfBusiness'],
    loginType: json['LoginType'],
    wardId: json['WardId'],
    enableVirtualClassRoom: json['EnableVirtualClassRoom'],
    enableVroomMeeting: json['EnableVroomMeeting'],
    enableVroomItAdminApproval: json['EnableVroomITAdminApproval'],
    enableVoice: json['EnableVoice'],
    isWebRtcEnabled: json['isWebRTCEnabled'],
    isTextChatEnabled: json['isTextChatEnabled'],
    isAudioBridgeEnabled: json['isAudioBridgeEnabled'],
    token: json['Token'],
    isFirstLogin: json['IsFirstLogin'],
    schoolName: json['SchoolName'],
    schoolShortName: json['SchoolShortName'],
  );

  @HiveField(0)
  final int branchId;

  @HiveField(1)
  final dynamic classes;

  @HiveField(20)
  final bool? enableVirtualClassRoom;

  @HiveField(21)
  final bool? enableVoice;

  @HiveField(22)
  final bool? enableVroomItAdminApproval;

  @HiveField(23)
  final bool? enableVroomMeeting;

  @HiveField(2)
  final int id;

  @HiveField(24)
  final bool? isAudioBridgeEnabled;

  @HiveField(3)
  final bool isCorporate;

  @HiveField(4)
  final bool isFirstLogin;

  @HiveField(5)
  final bool isLogistics;

  @HiveField(25)
  final bool? isTextChatEnabled;

  @HiveField(26)
  final bool? isWebRtcEnabled;

  @HiveField(6)
  final String loginType;

  @HiveField(7)
  final String mobile;

  @HiveField(8)
  final String name;

  @HiveField(9)
  final String orgType;

  @HiveField(10)
  final int organizationId;

  @HiveField(11)
  final List<Role> roles;

  @HiveField(18)
  final String? schoolName;

  @HiveField(19)
  final String? schoolShortName;

  @HiveField(12)
  final String sesid;

  @HiveField(13)
  final String token;

  @HiveField(14)
  final String typeOfBusiness;

  @HiveField(15)
  final String userName;

  @HiveField(16)
  final dynamic wardId;

  @HiveField(17)
  final int zoneId;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'UserName': userName,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'Roles': List<dynamic>.from(roles.map((x) => x.toJson())),
    'Classes': classes.runtimeType == String
        ? classes
        : List<dynamic>.from(classes.map((x) => x.toJson())),
    'Mobile': mobile,
    'Sesid': sesid,
    'IsCorporate': isCorporate,
    'IsLogistics': isLogistics,
    'OrgType': orgType,
    'TypeOfBusiness': typeOfBusiness,
    'LoginType': loginType,
    'WardId': wardId,
    'EnableVirtualClassRoom': enableVirtualClassRoom,
    'EnableVroomMeeting': enableVroomMeeting,
    'EnableVroomITAdminApproval': enableVroomItAdminApproval,
    'EnableVoice': enableVoice,
    'isWebRTCEnabled': isWebRtcEnabled,
    'isTextChatEnabled': isTextChatEnabled,
    'isAudioBridgeEnabled': isAudioBridgeEnabled,
    'Token': token,
    'IsFirstLogin': isFirstLogin,
    'SchoolName': schoolName,
    'SchoolShortName': schoolShortName,
  };
}

@HiveType(typeId: 14)
class UserClass {
  UserClass({
    required this.standard,
    required this.classId,
    required this.sections,
  });

  factory UserClass.fromJson(Map<String, dynamic> json) => UserClass(
    standard: json['Standard'],
    classId: json['ClassId'],
    sections: List<String>.from(json['Sections'].map((x) => x)),
  );

  @HiveField(0)
  final int classId;

  @HiveField(1)
  final List<String> sections;

  @HiveField(2)
  final String standard;

  Map<String, dynamic> toJson() => {
    'Standard': standard,
    'ClassId': classId,
    'Sections': List<dynamic>.from(sections.map((x) => x)),
  };
}

@HiveType(typeId: 3)
class Role {
  Role({required this.id, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) =>
      Role(id: json['Id'], name: json['Name']);

  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};
}
