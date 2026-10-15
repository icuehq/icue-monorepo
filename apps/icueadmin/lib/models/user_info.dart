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
    this.isTeacherConfigurationEnabled,
    required this.token,
    required this.isFirstLogin,
    this.schoolName,
    this.schoolShortName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['Id'] is int
        ? json['Id']
        : int.tryParse(json['Id']?.toString() ?? '') ?? 0,
    name: json['Name']?.toString() ?? '',
    userName: json['UserName']?.toString() ?? '',
    organizationId: json['OrganizationId'] is int
        ? json['OrganizationId']
        : int.tryParse(json['OrganizationId']?.toString() ?? '') ?? 0,
    zoneId: json['ZoneId'] is int
        ? json['ZoneId']
        : int.tryParse(json['ZoneId']?.toString() ?? '') ?? 0,
    branchId: json['BranchId'] is int
        ? json['BranchId']
        : int.tryParse(json['BranchId']?.toString() ?? '') ?? 0,
    roles: json['Roles'] == null
        ? []
        : List<Role>.from(
            (json['Roles'] as List).map(
              (x) => x is Role ? x : Role.fromJson(x as Map<String, dynamic>),
            ),
          ),
    classes: json['Classes'] == null
        ? <UserClass>[]
        : json['Classes'] is String
        ? json['Classes']
        : json['Classes'] is List
        ? List<UserClass>.from(
            (json['Classes'] as List).map(
              (x) => x is UserClass
                  ? x
                  : UserClass.fromJson(x as Map<String, dynamic>),
            ),
          )
        : json['Classes'],
    mobile: json['Mobile'],
    sesid: json['Sesid']?.toString() ?? '',
    isCorporate: json['IsCorporate'] ?? false,
    isLogistics: json['IsLogistics'] ?? false,
    orgType: json['OrgType']?.toString() ?? '',
    typeOfBusiness: json['TypeOfBusiness']?.toString() ?? '',
    loginType: json['LoginType']?.toString() ?? '',
    wardId: json['WardId'],
    enableVirtualClassRoom: json['EnableVirtualClassRoom'],
    enableVroomMeeting: json['EnableVroomMeeting'],
    enableVroomItAdminApproval: json['EnableVroomITAdminApproval'],
    enableVoice: json['EnableVoice'],
    isWebRtcEnabled: json['isWebRTCEnabled'],
    isTextChatEnabled: json['isTextChatEnabled'],
    isAudioBridgeEnabled: json['isAudioBridgeEnabled'],
    isTeacherConfigurationEnabled: json['isTeacherConfigurationEnabled'],
    token: json['Token']?.toString() ?? '',
    isFirstLogin: json['IsFirstLogin'] ?? false,
    schoolName: json['SchoolName'],
    schoolShortName: json['SchoolShortName'],
  );

  @HiveField(0)
  final int branchId;

  @HiveField(1)
  final dynamic classes;

  @HiveField(2)
  final int id;

  @HiveField(3)
  final bool isCorporate;

  @HiveField(4)
  final bool isFirstLogin;

  @HiveField(5)
  final bool isLogistics;

  @HiveField(6)
  final String loginType;

  @HiveField(7)
  final dynamic mobile;

  @HiveField(8)
  final String name;

  @HiveField(9)
  final String orgType;

  @HiveField(10)
  final int organizationId;

  @HiveField(11)
  final List<Role> roles;

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

  @HiveField(18)
  final String? schoolName;

  @HiveField(19)
  final String? schoolShortName;

  @HiveField(20)
  final bool? enableVirtualClassRoom;

  @HiveField(21)
  final bool? enableVoice;

  @HiveField(22)
  final bool? enableVroomItAdminApproval;

  @HiveField(23)
  final bool? enableVroomMeeting;

  @HiveField(24)
  final bool? isAudioBridgeEnabled;

  @HiveField(25)
  final bool? isTextChatEnabled;

  @HiveField(26)
  final bool? isWebRtcEnabled;

  @HiveField(27)
  final bool? isTeacherConfigurationEnabled;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'UserName': userName,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'Roles': List<dynamic>.from(roles.map((x) => x.toJson())),
    'Classes': classes is List
        ? List<dynamic>.from(
            (classes as List).map((x) => x is UserClass ? x.toJson() : x),
          )
        : classes,
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
    'isTeacherConfigurationEnabled': isTeacherConfigurationEnabled,
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
    this.subjectInfo,
  });

  factory UserClass.fromJson(Map<String, dynamic> json) => UserClass(
    standard: json['Standard']?.toString() ?? '',
    classId: json['ClassId'] is int
        ? json['ClassId']
        : int.tryParse(json['ClassId']?.toString() ?? '') ?? 0,
    sections: json['Sections'] == null
        ? []
        : List<String>.from(
            (json['Sections'] as List).map((x) => x.toString()),
          ),
    subjectInfo: json['SubjectInfo'] == null
        ? null
        : List<SubjectInfo>.from(
            (json['SubjectInfo'] as List).map(
              (x) => x is SubjectInfo
                  ? x
                  : SubjectInfo.fromJson(x as Map<String, dynamic>),
            ),
          ),
  );

  @HiveField(0)
  final int classId;

  @HiveField(1)
  final List<String> sections;

  @HiveField(2)
  final String standard;

  @HiveField(3)
  final List<SubjectInfo>? subjectInfo;

  Map<String, dynamic> toJson() => {
    'Standard': standard,
    'ClassId': classId,
    'Sections': List<dynamic>.from(sections.map((x) => x)),
    if (subjectInfo != null)
      'SubjectInfo': List<dynamic>.from(subjectInfo!.map((x) => x.toJson())),
  };
}

@HiveType(typeId: 23)
class SubjectInfo {
  SubjectInfo({required this.section, required this.subjects});

  factory SubjectInfo.fromJson(Map<String, dynamic> json) => SubjectInfo(
    section: json['Section']?.toString() ?? '',
    subjects: json['Subjects'] == null
        ? []
        : List<Subject>.from(
            (json['Subjects'] as List).map(
              (x) => x is Subject
                  ? x
                  : Subject.fromJson(x as Map<String, dynamic>),
            ),
          ),
  );

  @HiveField(0)
  final String section;

  @HiveField(1)
  final List<Subject> subjects;

  Map<String, dynamic> toJson() => {
    'Section': section,
    'Subjects': List<dynamic>.from(subjects.map((x) => x.toJson())),
  };
}

@HiveType(typeId: 24)
class Subject {
  Subject({required this.subjectId, required this.subject});

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    subjectId: json['SubjectId'] is int
        ? json['SubjectId']
        : int.tryParse(json['SubjectId']?.toString() ?? '') ?? 0,
    subject: json['Subject']?.toString() ?? '',
  );

  @HiveField(0)
  final int subjectId;

  @HiveField(1)
  final String subject;

  Map<String, dynamic> toJson() => {'SubjectId': subjectId, 'Subject': subject};
}

@HiveType(typeId: 3)
class Role {
  Role({required this.id, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) => Role(
    id: json['Id'] is int
        ? json['Id']
        : int.tryParse(json['Id']?.toString() ?? '') ?? 0,
    name: json['Name']?.toString() ?? '',
  );

  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};
}
