class ComplaintType {
  const ComplaintType({required this.type, required this.description});

  factory ComplaintType.fromJson(Map<String, dynamic> json) => ComplaintType(
    type: (json['ComplaintType'] as num).toInt(),
    description: json['ComplaintDesc'] as String? ?? '',
  );

  final int type;
  final String description;
}

/// Complaint progress as the server numbers it.
enum ComplaintStatus {
  open,
  inProgress,
  resolved;

  static ComplaintStatus fromCode(int code) =>
      code >= 0 && code < values.length ? values[code] : open;
}

class ComplaintResponse {
  const ComplaintResponse({
    required this.text,
    required this.userType,
    required this.dateString,
  });

  factory ComplaintResponse.fromJson(Map<String, dynamic> json) =>
      ComplaintResponse(
        text: json['Response'] as String? ?? '',
        userType: json['UserType'] as String? ?? '',
        dateString: json['DateString'] as String? ?? '',
      );

  final String text;

  /// `admin` or the responder's role.
  final String userType;

  /// `dd-MM-yyyy::HH:mm`.
  final String dateString;
}

class Complaint {
  const Complaint({
    required this.id,
    required this.type,
    required this.query,
    required this.status,
    required this.queryTime,
    required this.responses,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: (json['Id'] as num).toInt(),
    type: (json['ComplaintType'] as num).toInt(),
    query: json['Query'] as String? ?? '',
    status: ComplaintStatus.fromCode((json['Status'] as num?)?.toInt() ?? 0),
    queryTime: json['QueryTime'] as String? ?? '',
    responses: (json['Response'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ComplaintResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final int type;
  final String query;
  final ComplaintStatus status;

  /// `dd-MM-yyyy::HH:mm`.
  final String queryTime;
  final List<ComplaintResponse> responses;
}
