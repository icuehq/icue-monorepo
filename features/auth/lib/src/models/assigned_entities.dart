import 'dart:convert';

AssignedEntities assignedEntitiesFromJson(String str) =>
    AssignedEntities.fromJson(json.decode(str) as Map<String, dynamic>);

String assignedEntitiesToJson(AssignedEntities data) =>
    json.encode(data.toJson());

class AssignedEntities {
  AssignedEntities({required this.err, required this.message, this.data});

  factory AssignedEntities.fromJson(Map<String, dynamic> json) =>
      AssignedEntities(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data: json['data'] is List
            ? List<AssignedEntity>.from(
                (json['data'] as List<dynamic>).map(
                  (x) => AssignedEntity.fromJson(x as Map<String, dynamic>),
                ),
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
            (json['Classes'] as List<dynamic>).map(
              (x) => AssignedEntityClass.fromJson(x as Map<String, dynamic>),
            ),
          )
        : <AssignedEntityClass>[],
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
        standard:
            json['Standard'] as String? ?? json['standard'] as String? ?? '',
        classId: json['ClassId'] as int? ?? json['classId'] as int? ?? 0,
        standardType:
            json['StandardType'] as String? ?? json['standardType'] as String?,
        sections: json['Sections'] is List
            ? List<String>.from(
                (json['Sections'] as List<dynamic>).map((x) => x.toString()),
              )
            : <String>[],
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
