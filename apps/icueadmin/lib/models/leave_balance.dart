import 'dart:convert';

List<LeaveBalance> leaveBalanceListFromJson(dynamic data) {
  if (data == null) return [];
  if (data is String) {
    try {
      final decoded = json.decode(data);
      return leaveBalanceListFromJson(decoded);
    } catch (_) {
      return [];
    }
  }
  if (data is List) {
    return data
        .map((x) => LeaveBalance.fromJson(x as Map<String, dynamic>))
        .toList();
  }
  if (data is Map<String, dynamic>) {
    if (data['data'] is List) {
      return (data['data'] as List)
          .map((x) => LeaveBalance.fromJson(x as Map<String, dynamic>))
          .toList();
    }
  }
  return [];
}

String leaveBalanceListToJson(List<LeaveBalance> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class LeaveBalance {
  const LeaveBalance({
    required this.leavetypeFid,
    required this.leavetype,
    this.description,
    required this.isEmpAccess,
    required this.noOfDays,
    required this.leaveTaken,
    required this.balanceLeave,
    required this.isValid,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leavetypeFid: json['leavetype_fid'] is int
          ? json['leavetype_fid'] as int
          : int.tryParse(json['leavetype_fid']?.toString() ?? '') ?? 0,
      leavetype: (json['leavetype']?.toString() ?? '').trim(),
      description: json['description']?.toString(),
      isEmpAccess:
          json['is_emp_access'] == true ||
          json['is_emp_access']?.toString().toLowerCase() == 'true',
      noOfDays: json['noofdays']?.toString() ?? '0',
      leaveTaken: json['leavetaken']?.toString() ?? '0',
      balanceLeave: json['balanceleave']?.toString() ?? '0',
      isValid:
          json['isvalid'] == true ||
          json['isvalid']?.toString().toLowerCase() == 'true',
    );
  }

  final int leavetypeFid;
  final String leavetype;
  final String? description;
  final bool isEmpAccess;
  final String noOfDays;
  final String leaveTaken;
  final String balanceLeave;
  final bool isValid;

  double get allocatedDays => double.tryParse(noOfDays) ?? 0.0;
  double get takenDays => double.tryParse(leaveTaken) ?? 0.0;
  double get remainingDays => double.tryParse(balanceLeave) ?? 0.0;

  Map<String, dynamic> toJson() => {
    'leavetype_fid': leavetypeFid,
    'leavetype': leavetype,
    'description': description,
    'is_emp_access': isEmpAccess,
    'noofdays': noOfDays,
    'leavetaken': leaveTaken,
    'balanceleave': balanceLeave,
    'isvalid': isValid,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaveBalance &&
          runtimeType == other.runtimeType &&
          leavetypeFid == other.leavetypeFid;

  @override
  int get hashCode => leavetypeFid.hashCode;
}
