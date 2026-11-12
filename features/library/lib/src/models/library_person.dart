/// A student or teacher the desk found in the ERP (Node), about to borrow.
class LibraryPerson {
  const LibraryPerson({
    required this.memberType,
    required this.personErpId,
    required this.name,
    this.classId,
    this.className = '',
    this.section = '',
    this.admissionNumber = '',
    this.detail = '',
    this.photoUrl = '',
  });

  final String memberType;
  final int personErpId;
  final String name;
  final int? classId;
  final String className;
  final String section;
  final String admissionNumber;

  /// Class, section and admission number for the search result list; empty for teachers.
  final String detail;

  /// ERP photo of a student; empty when there is none.
  final String photoUrl;

  bool get isStudent => memberType == 'student';

  /// What the issue callable take as `person`.
  Map<String, Object?> toPayload() => {
    'memberType': memberType,
    'personErpId': personErpId,
    'name': name,
    'classId': ?classId,
    'className': className,
    'section': section,
    'admissionNumber': admissionNumber,
  };
}
