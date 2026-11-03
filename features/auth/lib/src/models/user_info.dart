import 'dart:convert';

import 'package:hive/hive.dart';

UserInfo userInfoFromJson(String str) =>
    UserInfo.fromJson(json.decode(str) as Map<String, dynamic>);

String userInfoToJson(UserInfo data) => json.encode(data.toJson());

@HiveType(typeId: 2)
class UserInfo {
  UserInfo({
    required this.id,
    required this.name,
    required this.userName,
    this.organizationId = 0,
    this.zoneId = 0,
    this.branchId = 0,
    this.roles = const [],
    this.classes,
    this.mobile = '',
    this.sesid = '',
    this.isCorporate = false,
    this.isLogistics = false,
    this.orgType = '',
    this.typeOfBusiness = '',
    this.loginType = '',
    this.wardId,
    required this.token,
    this.isFirstLogin = false,
    this.schoolName,
    this.schoolShortName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['Id'] as int? ?? json['id'] as int? ?? 0,
    name: json['Name'] as String? ?? json['name'] as String? ?? '',
    userName: json['UserName'] as String? ?? json['userName'] as String? ?? '',
    organizationId:
        json['OrganizationId'] as int? ?? json['organizationId'] as int? ?? 0,
    zoneId: json['ZoneId'] as int? ?? json['zoneId'] as int? ?? 0,
    branchId: json['BranchId'] as int? ?? json['branchId'] as int? ?? 0,
    roles: json['Roles'] != null
        ? List<Role>.from(
            (json['Roles'] as List<dynamic>).map(
              (x) => Role.fromJson(x as Map<String, dynamic>),
            ),
          )
        : <Role>[],
    classes: json['Classes'] == null
        ? <dynamic>[]
        : json['Classes'] is String
        ? json['Classes']
        : json['Classes'] is List
        ? List<UserClass>.from(
            (json['Classes'] as List<dynamic>).map(
              (x) => UserClass.fromJson(x as Map<String, dynamic>),
            ),
          )
        : json['Classes'],
    mobile: json['Mobile'] as String? ?? json['mobile'] as String? ?? '',
    sesid: json['Sesid'] as String? ?? json['sesid'] as String? ?? '',
    isCorporate:
        json['IsCorporate'] as bool? ?? json['isCorporate'] as bool? ?? false,
    isLogistics:
        json['IsLogistics'] as bool? ?? json['isLogistics'] as bool? ?? false,
    orgType: json['OrgType'] as String? ?? json['orgType'] as String? ?? '',
    typeOfBusiness:
        json['TypeOfBusiness'] as String? ??
        json['typeOfBusiness'] as String? ??
        '',
    loginType:
        json['LoginType'] as String? ?? json['loginType'] as String? ?? '',
    wardId: json['WardId'] ?? json['wardId'],
    token: json['Token'] as String? ?? json['token'] as String? ?? '',
    isFirstLogin:
        json['IsFirstLogin'] as bool? ?? json['isFirstLogin'] as bool? ?? false,
    schoolName: json['SchoolName'] as String? ?? json['schoolName'] as String?,
    schoolShortName:
        json['SchoolShortName'] as String? ??
        json['schoolShortName'] as String?,
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
  final String mobile;

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

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'UserName': userName,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'Roles': List<dynamic>.from(roles.map((x) => x.toJson())),
    'Classes': classes is String
        ? classes
        : classes is List
        ? List<dynamic>.from(
            (classes as List<dynamic>).map(
              (dynamic x) => (x as UserClass).toJson(),
            ),
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
    standard: json['Standard'] as String? ?? json['standard'] as String? ?? '',
    classId: json['ClassId'] as int? ?? json['classId'] as int? ?? 0,
    sections: json['Sections'] != null
        ? List<String>.from(
            (json['Sections'] as List<dynamic>).map((x) => x.toString()),
          )
        : <String>[],
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

  factory Role.fromJson(Map<String, dynamic> json) => Role(
    id: json['Id'] as int? ?? json['id'] as int? ?? 0,
    name: json['Name'] as String? ?? json['name'] as String? ?? '',
  );

  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};
}

class UserInfoAdapter extends TypeAdapter<UserInfo> {
  @override
  final int typeId = 2;

  @override
  UserInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserInfo(
      id: fields[2] as int? ?? 0,
      name: fields[8] as String? ?? '',
      userName: fields[15] as String? ?? '',
      organizationId: fields[10] as int? ?? 0,
      zoneId: fields[17] as int? ?? 0,
      branchId: fields[0] as int? ?? 0,
      roles: fields[11] != null ? (fields[11] as List).cast<Role>() : <Role>[],
      classes: fields[1],
      mobile: fields[7] as String? ?? '',
      sesid: fields[12] as String? ?? '',
      isCorporate: fields[3] as bool? ?? false,
      isLogistics: fields[5] as bool? ?? false,
      orgType: fields[9] as String? ?? '',
      typeOfBusiness: fields[14] as String? ?? '',
      loginType: fields[6] as String? ?? '',
      wardId: fields[16],
      token: fields[13] as String? ?? '',
      isFirstLogin: fields[4] as bool? ?? false,
      schoolName: fields[18] as String?,
      schoolShortName: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserInfo obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.branchId)
      ..writeByte(1)
      ..write(obj.classes)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.isCorporate)
      ..writeByte(4)
      ..write(obj.isFirstLogin)
      ..writeByte(5)
      ..write(obj.isLogistics)
      ..writeByte(6)
      ..write(obj.loginType)
      ..writeByte(7)
      ..write(obj.mobile)
      ..writeByte(8)
      ..write(obj.name)
      ..writeByte(9)
      ..write(obj.orgType)
      ..writeByte(10)
      ..write(obj.organizationId)
      ..writeByte(11)
      ..write(obj.roles)
      ..writeByte(12)
      ..write(obj.sesid)
      ..writeByte(13)
      ..write(obj.token)
      ..writeByte(14)
      ..write(obj.typeOfBusiness)
      ..writeByte(15)
      ..write(obj.userName)
      ..writeByte(16)
      ..write(obj.wardId)
      ..writeByte(17)
      ..write(obj.zoneId)
      ..writeByte(18)
      ..write(obj.schoolName)
      ..writeByte(19)
      ..write(obj.schoolShortName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserClassAdapter extends TypeAdapter<UserClass> {
  @override
  final int typeId = 14;

  @override
  UserClass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserClass(
      standard: fields[2] as String? ?? '',
      classId: fields[0] as int? ?? 0,
      sections: fields[1] != null
          ? (fields[1] as List).cast<String>()
          : <String>[],
    );
  }

  @override
  void write(BinaryWriter writer, UserClass obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.classId)
      ..writeByte(1)
      ..write(obj.sections)
      ..writeByte(2)
      ..write(obj.standard);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserClassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoleAdapter extends TypeAdapter<Role> {
  @override
  final int typeId = 3;

  @override
  Role read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Role(id: fields[0] as int? ?? 0, name: fields[1] as String? ?? '');
  }

  @override
  void write(BinaryWriter writer, Role obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
