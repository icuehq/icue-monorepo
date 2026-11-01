import 'package:icue_firebase/icue_firebase.dart';

String incidentStatusLabel(String s) => switch (s) {
  'open' => 'Open',
  'resolved' => 'Resolved',
  _ => s,
};

String incidentKindLabel(String k) => switch (k) {
  'lost' => 'Lost',
  'damaged' => 'Damaged',
  _ => k,
};

String incidentSeverityLabel(String? s) => switch (s) {
  'minor' => 'Minor',
  'moderate' => 'Moderate',
  'severe' => 'Severe',
  _ => s ?? '–',
};

String incidentResolutionLabel(String? r) => switch (r) {
  'repaired' => 'Repaired',
  'replaced' => 'Replaced',
  'written_off' => 'Written off',
  'charged' => 'Penalty charged',
  'dismissed' => 'Dismissed',
  _ => r ?? '–',
};

/// A lost or damaged book incident (FRS 11.14).
class LibIncident {
  const LibIncident({
    required this.id,
    required this.incidentNumber,
    required this.kind,
    required this.copyId,
    required this.accessionNo,
    required this.catalogueId,
    required this.libraryId,
    required this.campusId,
    required this.status,
    required this.reportedDate,
    this.memberId,
    this.memberType,
    this.personErpId,
    this.loanId,
    this.severity,
    this.description,
    this.charge = 0,
    this.repairCost,
    this.repairStatus,
    this.resolution,
    this.resolutionRemarks,
    this.resolvedAt,
    this.createdAt,
  });

  factory LibIncident.fromMap(String id, Map<String, dynamic> m) => LibIncident(
    id: id,
    incidentNumber: m['incidentNumber'] as String? ?? id,
    kind: m['kind'] as String? ?? 'damaged',
    copyId: m['copyId'] as String? ?? '',
    accessionNo: m['accessionNo'] as String? ?? '',
    catalogueId: m['catalogueId'] as String? ?? '',
    libraryId: m['libraryId'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    status: m['status'] as String? ?? 'open',
    reportedDate: m['reportedDate'] as String? ?? '',
    memberId: m['memberId'] as String?,
    memberType: m['memberType'] as String?,
    personErpId: (m['personErpId'] as num?)?.toInt(),
    loanId: m['loanId'] as String?,
    severity: m['severity'] as String?,
    description: m['description'] as String?,
    charge: (m['charge'] as num? ?? 0).toDouble(),
    repairCost: (m['repairCost'] as num?)?.toDouble(),
    repairStatus: m['repairStatus'] as String?,
    resolution: m['resolution'] as String?,
    resolutionRemarks: m['resolutionRemarks'] as String?,
    resolvedAt: m['resolvedAt'] is Timestamp
        ? (m['resolvedAt'] as Timestamp).toDate()
        : null,
    createdAt: m['createdAt'] is Timestamp
        ? (m['createdAt'] as Timestamp).toDate()
        : null,
  );

  final String id;
  final String incidentNumber;
  final String kind;
  final String copyId;
  final String accessionNo;
  final String catalogueId;
  final String libraryId;
  final int campusId;
  final String status;
  final String reportedDate;
  final String? memberId;
  final String? memberType;
  final int? personErpId;
  final String? loanId;
  final String? severity;
  final String? description;
  final double charge;
  final double? repairCost;
  final String? repairStatus;
  final String? resolution;
  final String? resolutionRemarks;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';
  String? get memberLabel => personErpId == null
      ? null
      : '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
