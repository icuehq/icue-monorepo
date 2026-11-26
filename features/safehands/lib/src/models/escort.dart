/// A person allowed to pick the student up, with a photo for the driver to check.
class Escort {
  const Escort({
    required this.id,
    required this.type,
    required this.name,
    required this.relation,
    required this.photoUrl,
    this.mobile,
    this.fromDate,
    this.toDate,
  });

  factory Escort.fromJson(Map<String, dynamic> json) => Escort(
    id: (json['Id'] as num).toInt(),
    type: json['Type'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    relation: json['Relation'] as String? ?? '',
    photoUrl: json['PhotoUrl'] as String? ?? '',
    mobile: json['Mobile']?.toString(),
    fromDate: json['FromDate'] as String?,
    toDate: json['ToDate'] as String?,
  );

  final int id;

  /// `PERMANENT` or `TEMPORARY` (temporary escorts have a date range).
  final String type;
  final String name;
  final String relation;
  final String photoUrl;
  final String? mobile;
  final String? fromDate;
  final String? toDate;

  bool get isTemporary => type == escortTemporary;
}

const escortPermanent = 'PERMANENT';
const escortTemporary = 'TEMPORARY';
