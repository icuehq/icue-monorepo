/// A student or teacher the desk found in the ERP (Node), about to borrow or reserve.
class LibraryPerson {
  const LibraryPerson({
    required this.memberType,
    required this.personErpId,
    required this.name,
    this.classId,
    this.detail = '',
  });

  final String memberType;
  final int personErpId;
  final String name;
  final int? classId;

  /// Class, section and admission number for the search result list; empty for teachers.
  final String detail;

  bool get isStudent => memberType == 'student';

  /// What the issue and reserve callables take as `person`.
  Map<String, Object?> toPayload() => {
    'memberType': memberType,
    'personErpId': personErpId,
    'name': name,
    'classId': ?classId,
  };
}
