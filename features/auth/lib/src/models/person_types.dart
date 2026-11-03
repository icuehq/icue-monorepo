import 'dart:convert';

import 'package:hive/hive.dart';

PersonTypes personTypesFromJson(String str) =>
    PersonTypes.fromJson(json.decode(str) as Map<String, dynamic>);

String personTypesToJson(PersonTypes data) => json.encode(data.toJson());

class PersonTypes {
  PersonTypes({required this.err, required this.message, required this.data});

  factory PersonTypes.fromJson(Map<String, dynamic> json) => PersonTypes(
    err: json['err'] as bool? ?? false,
    message: json['message'] as String? ?? '',
    data: json['data'] is List
        ? List<PersonType>.from(
            (json['data'] as List<dynamic>).map(
              (x) => PersonType.fromJson(x as Map<String, dynamic>),
            ),
          )
        : <PersonType>[],
  );

  final List<PersonType> data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

@HiveType(typeId: 15)
class PersonType {
  PersonType({required this.id, required this.category});

  factory PersonType.fromJson(Map<String, dynamic> json) => PersonType(
    id: json['Id'] as int? ?? json['id'] as int? ?? 0,
    category: json['Category'] as String? ?? json['category'] as String? ?? '',
  );

  @HiveField(0)
  final String category;

  @HiveField(1)
  final int id;

  Map<String, dynamic> toJson() => {'Id': id, 'Category': category};
}

class PersonTypeAdapter extends TypeAdapter<PersonType> {
  @override
  final int typeId = 15;

  @override
  PersonType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersonType(
      category: fields[0] as String? ?? '',
      id: fields[1] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PersonType obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.category)
      ..writeByte(1)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
