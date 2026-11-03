import 'dart:convert';

import 'package:hive/hive.dart';

Branchs branchsFromJson(String str) =>
    Branchs.fromJson(json.decode(str) as Map<String, dynamic>);

String branchsToJson(Branchs data) => json.encode(data.toJson());

class Branchs {
  Branchs({required this.err, required this.message, required this.data});

  factory Branchs.fromJson(Map<String, dynamic> json) => Branchs(
    err: json['err'] as bool? ?? false,
    message: json['message'] as String? ?? '',
    data: json['data'] is List
        ? List<Branch>.from(
            (json['data'] as List<dynamic>).map(
              (x) => Branch.fromJson(x as Map<String, dynamic>),
            ),
          )
        : <Branch>[],
  );

  final List<Branch> data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

@HiveType(typeId: 22)
class Branch {
  Branch({
    required this.id,
    required this.schoolName,
    required this.schoolShortName,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['Id'] as int? ?? json['id'] as int? ?? 0,
    schoolName:
        json['SchoolName'] as String? ?? json['schoolName'] as String? ?? '',
    schoolShortName:
        json['SchoolShortName'] as String? ??
        json['schoolShortName'] as String? ??
        '',
  );

  @HiveField(0)
  final int id;

  @HiveField(1)
  final String schoolName;

  @HiveField(2)
  final String schoolShortName;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'SchoolName': schoolName,
    'SchoolShortName': schoolShortName,
  };
}

class BranchAdapter extends TypeAdapter<Branch> {
  @override
  final int typeId = 22;

  @override
  Branch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Branch(
      id: fields[0] as int? ?? 0,
      schoolName: fields[1] as String? ?? '',
      schoolShortName: fields[2] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Branch obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.schoolName)
      ..writeByte(2)
      ..write(obj.schoolShortName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
