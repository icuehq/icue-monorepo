import 'dart:convert';

LeaveRequestPayload leaveRequestPayloadFromJson(String str) =>
    LeaveRequestPayload.fromJson(json.decode(str) as Map<String, dynamic>);

String leaveRequestPayloadToJson(LeaveRequestPayload data) =>
    json.encode(data.toJson());

class LeaveRequestPayload {
  const LeaveRequestPayload({
    this.leaveUid = 0,
    required this.leavetypeFid,
    required this.leavetype,
    required this.leavebalance,
    required this.employeeId,
    required this.fromdate,
    required this.todate,
    required this.noofdays,
    required this.reason,
    this.status = 'Requested',
    required this.halfday,
    required this.createdby,
  });

  factory LeaveRequestPayload.fromJson(Map<String, dynamic> json) {
    return LeaveRequestPayload(
      leaveUid: json['leave_uid'] is int
          ? json['leave_uid'] as int
          : int.tryParse(json['leave_uid']?.toString() ?? '') ?? 0,
      leavetypeFid: json['leavetype_fid'] is int
          ? json['leavetype_fid'] as int
          : int.tryParse(json['leavetype_fid']?.toString() ?? '') ?? 0,
      leavetype: json['leavetype']?.toString() ?? '',
      leavebalance: json['leavebalance'] is num
          ? json['leavebalance']
          : num.tryParse(json['leavebalance']?.toString() ?? '') ??
                json['leavebalance']?.toString() ??
                0,
      employeeId: json['employee_id'] is int
          ? json['employee_id'] as int
          : int.tryParse(json['employee_id']?.toString() ?? '') ?? 0,
      fromdate: json['fromdate']?.toString() ?? '',
      todate: json['todate']?.toString() ?? '',
      noofdays: json['noofdays'] is num
          ? json['noofdays']
          : num.tryParse(json['noofdays']?.toString() ?? '') ??
                json['noofdays']?.toString() ??
                1,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Requested',
      halfday:
          json['halfday'] == true ||
          json['halfday']?.toString().toLowerCase() == 'true',
      createdby: json['createdby'] is int
          ? json['createdby'] as int
          : int.tryParse(json['createdby']?.toString() ?? '') ?? 0,
    );
  }

  final int leaveUid;
  final int leavetypeFid;
  final String leavetype;
  final dynamic leavebalance;
  final int employeeId;
  final String fromdate;
  final String todate;
  final dynamic noofdays;
  final String reason;
  final String status;
  final bool halfday;
  final int createdby;

  Map<String, dynamic> toJson() => {
    'leave_uid': leaveUid,
    'leavetype_fid': leavetypeFid,
    'leavetype': leavetype,
    'leavebalance': leavebalance,
    'employee_id': employeeId,
    'fromdate': fromdate,
    'todate': todate,
    'noofdays': noofdays,
    'reason': reason,
    'status': status,
    'halfday': halfday,
    'createdby': createdby,
  };
}
