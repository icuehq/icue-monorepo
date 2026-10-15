// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      id: fields[2] as int,
      name: fields[8] as String,
      userName: fields[15] as String,
      organizationId: fields[10] as int,
      zoneId: fields[17] as int,
      branchId: fields[0] as int,
      roles: (fields[11] as List).cast<Role>(),
      classes: fields[1] as dynamic,
      mobile: fields[7] as dynamic,
      sesid: fields[12] as String,
      isCorporate: fields[3] as bool,
      isLogistics: fields[5] as bool,
      orgType: fields[9] as String,
      typeOfBusiness: fields[14] as String,
      loginType: fields[6] as String,
      wardId: fields[16] as dynamic,
      enableVirtualClassRoom: fields[20] as bool?,
      enableVroomMeeting: fields[23] as bool?,
      enableVroomItAdminApproval: fields[22] as bool?,
      enableVoice: fields[21] as bool?,
      isWebRtcEnabled: fields[26] as bool?,
      isTextChatEnabled: fields[25] as bool?,
      isAudioBridgeEnabled: fields[24] as bool?,
      isTeacherConfigurationEnabled: fields[27] as bool?,
      token: fields[13] as String,
      isFirstLogin: fields[4] as bool,
      schoolName: fields[18] as String?,
      schoolShortName: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserInfo obj) {
    writer
      ..writeByte(28)
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
      ..write(obj.schoolShortName)
      ..writeByte(20)
      ..write(obj.enableVirtualClassRoom)
      ..writeByte(21)
      ..write(obj.enableVoice)
      ..writeByte(22)
      ..write(obj.enableVroomItAdminApproval)
      ..writeByte(23)
      ..write(obj.enableVroomMeeting)
      ..writeByte(24)
      ..write(obj.isAudioBridgeEnabled)
      ..writeByte(25)
      ..write(obj.isTextChatEnabled)
      ..writeByte(26)
      ..write(obj.isWebRtcEnabled)
      ..writeByte(27)
      ..write(obj.isTeacherConfigurationEnabled);
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
      standard: fields[2] as String,
      classId: fields[0] as int,
      sections: (fields[1] as List).cast<String>(),
      subjectInfo: (fields[3] as List?)?.cast<SubjectInfo>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserClass obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.classId)
      ..writeByte(1)
      ..write(obj.sections)
      ..writeByte(2)
      ..write(obj.standard)
      ..writeByte(3)
      ..write(obj.subjectInfo);
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

class SubjectInfoAdapter extends TypeAdapter<SubjectInfo> {
  @override
  final int typeId = 23;

  @override
  SubjectInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubjectInfo(
      section: fields[0] as String,
      subjects: (fields[1] as List).cast<Subject>(),
    );
  }

  @override
  void write(BinaryWriter writer, SubjectInfo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.section)
      ..writeByte(1)
      ..write(obj.subjects);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubjectAdapter extends TypeAdapter<Subject> {
  @override
  final int typeId = 24;

  @override
  Subject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subject(
      subjectId: fields[0] as int,
      subject: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Subject obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.subjectId)
      ..writeByte(1)
      ..write(obj.subject);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAdapter &&
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
    return Role(
      id: fields[0] as int,
      name: fields[1] as String,
    );
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
