/// Parent login response: the parent's id, session token and linked students.
class ParentUser {
  const ParentUser({required this.id, required this.students, this.token});

  factory ParentUser.fromJson(Map<String, dynamic> json) => ParentUser(
    id: (json['Id'] as num).toInt(),
    token: json['Token'] as String?,
    students: (json['Students'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ParentStudent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String? token;
  final List<ParentStudent> students;
}

class ParentAppFeature {
  const ParentAppFeature({required this.id, required this.name});

  factory ParentAppFeature.fromJson(Map<String, dynamic> json) =>
      ParentAppFeature(
        id: (json['Id'] as num).toInt(),
        name: json['Name'] as String? ?? '',
      );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'Id': id, 'Name': name};
}

List<double>? _doubles(dynamic value) => value == null
    ? null
    : (value as List<dynamic>).map((e) => (e as num).toDouble()).toList();

/// A student linked to the signed-in parent. JSON keys match the server.
class ParentStudent {
  const ParentStudent({
    required this.organizationId,
    required this.branchId,
    required this.zoneId,
    required this.id,
    required this.name,
    required this.admissionNumber,
    required this.classId,
    required this.gender,
    required this.roles,
    required this.parentAppFeature,
    this.rollNo,
    this.standard,
    this.section,
    this.parentName,
    this.primaryContact,
    this.secondaryContact,
    this.pickPoint,
    this.pickArea,
    this.pickCoordinates,
    this.dropArea,
    this.dropPoint,
    this.dropCoordinates,
    this.isMessOpted,
    this.isTransportOpted,
    this.area,
    this.showRoutePanel,
    this.showNotification,
    this.showContactNo,
    this.showEta,
    this.etaInfo,
    this.socketServer,
    this.locSocketServer,
    this.isLeavesDisabled,
    this.isHidePayments,
    this.isEscortPhotos,
    this.schoolName,
    this.schoolPoint,
    this.showClassSection = false,
    this.enabledParentVehicles,
    this.isServerLessConfig,
  });

  factory ParentStudent.fromJson(Map<String, dynamic> json) => ParentStudent(
    organizationId: (json['OrganizationId'] as num).toInt(),
    branchId: (json['BranchId'] as num).toInt(),
    zoneId: (json['ZoneId'] as num).toInt(),
    id: (json['Id'] as num).toInt(),
    name: json['Name'] as String? ?? '',
    rollNo: json['RollNo'] as String?,
    admissionNumber: json['AdmissionNumber'] as String? ?? '',
    classId: (json['ClassId'] as num?)?.toInt() ?? 0,
    standard: json['Standard'] as String?,
    section: json['Section'] as String?,
    gender: json['Gender'] as String? ?? '',
    parentName: json['ParentName'] as String?,
    primaryContact: json['PrimaryContact'] as String?,
    secondaryContact: json['SecondaryContact'] as String?,
    pickPoint: json['PickPoint'] as String?,
    pickArea: json['PickArea'] as String?,
    pickCoordinates: _doubles(json['PickCoordinates']) ?? <double>[],
    dropArea: json['DropArea'] as String?,
    dropPoint: json['DropPoint'] as String?,
    dropCoordinates: _doubles(json['DropCoordinates']) ?? <double>[],
    roles: (json['Roles'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ParentAppFeature.fromJson(e as Map<String, dynamic>))
        .toList(),
    isMessOpted: json['IsMessOpted'] as bool?,
    isTransportOpted: json['IsTransportOpted'] as bool?,
    area: json['Area'],
    parentAppFeature: ParentAppFeature.fromJson(
      json['ParentAppFeature'] as Map<String, dynamic>,
    ),
    showRoutePanel: json['ShowRoutePanel'] as bool?,
    showNotification: json['ShowNotification'] as bool?,
    showContactNo: json['ShowContactNo'] as bool?,
    showEta: json['ShowETA'] as bool?,
    etaInfo: json['ETAINFO'] as String?,
    socketServer: json['socketserver'] as String?,
    locSocketServer: json['locSocketServer'] as String?,
    isLeavesDisabled: json['IsLeavesDisabled'] as bool?,
    isHidePayments: json['IsHidePayments'] as bool?,
    isEscortPhotos: json['IsEscortPhotos'] as bool?,
    schoolName: json['SchoolName'] as String?,
    schoolPoint: _doubles(json['SchoolPoint']) ?? <double>[],
    showClassSection: json['ShowClsSec'] as bool? ?? false,
    enabledParentVehicles: json['EnabledParentVehicles'] as bool?,
    isServerLessConfig: json['IsServerLessCnfg'] as bool?,
  );

  final int organizationId;
  final int branchId;
  final int zoneId;
  final int id;
  final String name;
  final String? rollNo;
  final String admissionNumber;
  final int classId;
  final String? standard;
  final String? section;
  final String gender;
  final String? parentName;
  final String? primaryContact;
  final String? secondaryContact;
  final String? pickPoint;
  final String? pickArea;
  final List<double>? pickCoordinates;
  final String? dropArea;
  final String? dropPoint;
  final List<double>? dropCoordinates;
  final List<ParentAppFeature> roles;
  final bool? isMessOpted;
  final bool? isTransportOpted;
  final Object? area;
  final ParentAppFeature parentAppFeature;
  final bool? showRoutePanel;
  final bool? showNotification;
  final bool? showContactNo;
  final bool? showEta;
  final String? etaInfo;
  final String? socketServer;
  final String? locSocketServer;
  final bool? isLeavesDisabled;
  final bool? isHidePayments;
  final bool? isEscortPhotos;
  final String? schoolName;
  final List<double>? schoolPoint;
  final bool showClassSection;
  final bool? enabledParentVehicles;
  final bool? isServerLessConfig;

  /// "Class - Section" when the school shows it, else null.
  String? get classSection => showClassSection ? '$standard - $section' : null;

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    'PickCoordinates': pickCoordinates,
    'DropArea': dropArea,
    'DropPoint': dropPoint,
    'DropCoordinates': dropCoordinates,
    'Roles': roles.map((e) => e.toJson()).toList(),
    'IsMessOpted': isMessOpted,
    'IsTransportOpted': isTransportOpted,
    'Area': area,
    'ParentAppFeature': parentAppFeature.toJson(),
    'ShowRoutePanel': showRoutePanel,
    'ShowNotification': showNotification,
    'ShowContactNo': showContactNo,
    'ShowETA': showEta,
    'ETAINFO': etaInfo,
    'socketserver': socketServer,
    'locSocketServer': locSocketServer,
    'IsLeavesDisabled': isLeavesDisabled,
    'IsHidePayments': isHidePayments,
    'IsEscortPhotos': isEscortPhotos,
    'SchoolName': schoolName,
    'SchoolPoint': schoolPoint,
    'ShowClsSec': showClassSection,
    'EnabledParentVehicles': enabledParentVehicles,
    'IsServerLessCnfg': isServerLessConfig,
  };
}
