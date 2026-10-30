import 'package:routes/src/models/routes.dart';

class Metadatum {
  const Metadatum({this.total = 0, this.pageNumber = 1, this.pageSize = 100});

  factory Metadatum.fromJson(Map<String, dynamic> json) => Metadatum(
    total: json['total'] as int? ?? 0,
    pageNumber: json['pageNumber'] as int? ?? 1,
    pageSize: json['pageSize'] as int? ?? 100,
  );

  final int total;
  final int pageNumber;
  final int pageSize;

  Map<String, dynamic> toJson() => {
    'total': total,
    'pageNumber': pageNumber,
    'pageSize': pageSize,
  };
}

class StudentData {
  const StudentData({
    required this.id,
    required this.name,
    this.admissionNumber = '',
    this.section = '',
    this.rollNo = '',
    this.standard = '',
    this.classId = 0,
    this.pickPoint = '',
    this.dropPoint = '',
    this.pickArea = '',
    this.dropArea = '',
    this.mode = const <RouteMode>[],
    this.routes = const <String>[],
    this.routeIds = const <String>[],
  });

  factory StudentData.fromJson(Map<String, dynamic> json) => StudentData(
    id: json['Id'] as int? ?? 0,
    name: json['Name'] as String? ?? '',
    admissionNumber: json['AdmissionNumber'] as String? ?? '',
    section: json['Section'] as String? ?? '',
    rollNo: json['RollNo'] as String? ?? '',
    standard: json['Standard'] as String? ?? '',
    classId: json['ClassId'] as int? ?? 0,
    pickPoint: json['PickPoint'] as String? ?? '',
    dropPoint: json['DropPoint'] as String? ?? '',
    pickArea: json['PickArea'] as String? ?? '',
    dropArea: json['DropArea'] as String? ?? '',
    mode: json['mode'] is List
        ? (json['mode'] as List)
              .map((x) => RouteMode.fromString(x.toString()))
              .toList()
        : const <RouteMode>[],
    routes: json['routes'] is List
        ? List<String>.from((json['routes'] as List).map((x) => x.toString()))
        : const <String>[],
    routeIds: json['routeIds'] is List
        ? List<String>.from((json['routeIds'] as List).map((x) => x.toString()))
        : const <String>[],
  );

  final int id;
  final String name;
  final String admissionNumber;
  final String section;
  final String rollNo;
  final String standard;
  final int classId;
  final String pickPoint;
  final String dropPoint;
  final String pickArea;
  final String dropArea;
  final List<RouteMode> mode;
  final List<String> routes;
  final List<String> routeIds;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'AdmissionNumber': admissionNumber,
    'Section': section,
    'RollNo': rollNo,
    'Standard': standard,
    'ClassId': classId,
    'PickPoint': pickPoint,
    'DropPoint': dropPoint,
    'PickArea': pickArea,
    'DropArea': dropArea,
    'mode': mode.map((x) => x.label).toList(),
    'routes': routes,
    'routeIds': routeIds,
  };
}

class Student {
  const Student({
    this.data = const <StudentData>[],
    this.metadata = const <Metadatum>[],
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    metadata: json['metadata'] is List
        ? (json['metadata'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Metadatum.fromJson)
              .toList()
        : const <Metadatum>[],
    data: json['data'] is List
        ? (json['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map(StudentData.fromJson)
              .toList()
        : const <StudentData>[],
  );

  final List<StudentData> data;
  final List<Metadatum> metadata;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.map((x) => x.toJson()).toList(),
    'data': data.map((x) => x.toJson()).toList(),
  };
}
