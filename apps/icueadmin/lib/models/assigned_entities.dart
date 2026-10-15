// To parse this JSON data, do
//
//     final assignedEntities = assignedEntitiesFromJson(jsonString);

// ignore_for_file: unnecessary_lambdas

import 'dart:convert';

AssignedEntities assignedEntitiesFromJson(String str) =>
    AssignedEntities.fromJson(json.decode(str));

String assignedEntitiesToJson(AssignedEntities data) =>
    json.encode(data.toJson());

class AssignedEntities {
  AssignedEntities({required this.err, required this.message, this.data});

  factory AssignedEntities.fromJson(Map<String, dynamic> json) =>
      AssignedEntities(
        err: json['err'] ?? false,
        message: json['message'] ?? '',
        data: json['data'] is List
            ? List<AssignedEntity>.from(
                (json['data'] as List).map((x) => AssignedEntity.fromJson(x)),
              )
            : null,
      );

  final List<AssignedEntity>? data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data == null
        ? null
        : List<dynamic>.from(data!.map((x) => x.toJson())),
  };
}

class AssignedEntity {
  AssignedEntity({required this.classes});

  factory AssignedEntity.fromJson(Map<String, dynamic> json) => AssignedEntity(
    classes: json['Classes'] is List
        ? List<AssignedEntityClass>.from(
            (json['Classes'] as List).map(
              (x) => AssignedEntityClass.fromJson(x),
            ),
          )
        : [],
  );

  final List<AssignedEntityClass> classes;

  Map<String, dynamic> toJson() => {
    'Classes': List<dynamic>.from(classes.map((x) => x.toJson())),
  };
}

class AssignedEntityClass {
  AssignedEntityClass({
    required this.standard,
    required this.classId,
    this.standardType,
    required this.sections,
  });

  factory AssignedEntityClass.fromJson(Map<String, dynamic> json) =>
      AssignedEntityClass(
        standard: json['Standard'] ?? '',
        classId: json['ClassId'] ?? 0,
        standardType: json['StandardType'],
        sections: json['Sections'] is List
            ? List<String>.from(
                (json['Sections'] as List).map((x) => x.toString()),
              )
            : [],
      );

  final int classId;
  final List<String> sections;
  final String standard;
  final String? standardType;

  Map<String, dynamic> toJson() => {
    'Standard': standard,
    'ClassId': classId,
    'StandardType': standardType,
    'Sections': List<dynamic>.from(sections.map((x) => x)),
  };
}
