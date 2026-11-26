/// A gate pass a parent requested for a student (`/getStuGatePass`).
class ParentGatePassRequest {
  const ParentGatePassRequest({
    required this.id,
    required this.gatePassType,
    required this.status,
    required this.statusDate,
  });

  factory ParentGatePassRequest.fromJson(Map<String, dynamic> json) =>
      ParentGatePassRequest(
        id: (json['Id'] as num).toInt(),
        gatePassType: json['GatePassType'] as String? ?? '',
        status: json['Status'] as String? ?? '',
        statusDate: json['StatusDt'] as String?,
      );

  final int id;

  /// Category code; match it with `GatePassType.category` for the display name.
  final String gatePassType;
  final String status;
  final String? statusDate;
}
