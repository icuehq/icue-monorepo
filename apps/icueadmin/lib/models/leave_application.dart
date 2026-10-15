import 'dart:convert';

List<LeaveApplication> leaveApplicationListFromJson(dynamic data) {
  if (data == null) return [];
  if (data is String) {
    try {
      final decoded = json.decode(data);
      return leaveApplicationListFromJson(decoded);
    } catch (_) {
      return [];
    }
  }
  if (data is List) {
    return data
        .map((x) => LeaveApplication.fromJson(x as Map<String, dynamic>))
        .toList();
  }
  if (data is Map<String, dynamic>) {
    if (data['data'] is List) {
      return (data['data'] as List)
          .map((x) => LeaveApplication.fromJson(x as Map<String, dynamic>))
          .toList();
    }
  }
  return [];
}

String leaveApplicationListToJson(List<LeaveApplication> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class LeaveApplication {
  const LeaveApplication({
    required this.leaveUid,
    required this.employeeId,
    required this.leavetypeFid,
    this.requestedtoFid,
    this.requestedDate,
    this.fromDate,
    this.toDate,
    required this.noOfDays,
    required this.halfDay,
    this.halfDaySlot,
    this.reason,
    this.approvedOrRejectedById,
    this.approveOrRejectionRemarks,
    required this.status,
    this.createdOn,
    this.createdBy,
    this.updatedOn,
    this.updatedBy,
    this.orgId,
    required this.leaveType,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      leaveUid: json['leave_uid'] is int
          ? json['leave_uid'] as int
          : int.tryParse(json['leave_uid']?.toString() ?? '') ?? 0,
      employeeId: json['employee_id'] is int
          ? json['employee_id'] as int
          : int.tryParse(json['employee_id']?.toString() ?? '') ?? 0,
      leavetypeFid: json['leavetype_fid'] is int
          ? json['leavetype_fid'] as int
          : int.tryParse(json['leavetype_fid']?.toString() ?? '') ?? 0,
      requestedtoFid: json['requestedto_fid'],
      requestedDate: _parseDate(json['requesteddate']),
      fromDate: _parseDate(json['fromdate']),
      toDate: _parseDate(json['todate']),
      noOfDays: json['noofdays'] is num
          ? json['noofdays'] as num
          : num.tryParse(json['noofdays']?.toString() ?? '') ?? 1,
      halfDay:
          json['halfday'] == true ||
          json['halfday']?.toString().toLowerCase() == 'true',
      halfDaySlot: json['halfdayslot']?.toString(),
      reason: json['reason']?.toString(),
      approvedOrRejectedById: json['approvedorrejectedbyid'] is int
          ? json['approvedorrejectedbyid'] as int
          : int.tryParse(json['approvedorrejectedbyid']?.toString() ?? ''),
      approveOrRejectionRemarks: json['approveorrejectionremarks']?.toString(),
      status: json['status']?.toString() ?? 'Requested',
      createdOn: _parseDate(json['createdon']),
      createdBy: json['createdby'],
      updatedOn: _parseDate(json['updatedon']),
      updatedBy: json['updatedby'],
      orgId: json['org_id'],
      leaveType: (json['leavetype']?.toString() ?? '').trim(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString();
    if (str.isEmpty || str == '{NULL}') return null;
    return DateTime.tryParse(str);
  }

  final int leaveUid;
  final int employeeId;
  final int leavetypeFid;
  final dynamic requestedtoFid;
  final DateTime? requestedDate;
  final DateTime? fromDate;
  final DateTime? toDate;
  final num noOfDays;
  final bool halfDay;
  final String? halfDaySlot;
  final String? reason;
  final int? approvedOrRejectedById;
  final String? approveOrRejectionRemarks;
  final String status;
  final DateTime? createdOn;
  final dynamic createdBy;
  final DateTime? updatedOn;
  final dynamic updatedBy;
  final dynamic orgId;
  final String leaveType;

  String get formattedDuration {
    if (halfDay) return 'Half Day (0.5d)';
    if (noOfDays == noOfDays.roundToDouble()) {
      return '${noOfDays.toInt()} ${noOfDays == 1 ? "Day" : "Days"}';
    }
    return '$noOfDays Days';
  }

  Map<String, dynamic> toJson() => {
    'leave_uid': leaveUid,
    'employee_id': employeeId,
    'leavetype_fid': leavetypeFid,
    'requestedto_fid': requestedtoFid,
    'requesteddate': requestedDate?.toIso8601String(),
    'fromdate': fromDate?.toIso8601String(),
    'todate': toDate?.toIso8601String(),
    'noofdays': noOfDays,
    'halfday': halfDay,
    'halfdayslot': halfDaySlot,
    'reason': reason,
    'approvedorrejectedbyid': approvedOrRejectedById,
    'approveorrejectionremarks': approveOrRejectionRemarks,
    'status': status,
    'createdon': createdOn?.toIso8601String(),
    'createdby': createdBy,
    'updatedon': updatedOn?.toIso8601String(),
    'updatedby': updatedBy,
    'org_id': orgId,
    'leavetype': leaveType,
  };
}
