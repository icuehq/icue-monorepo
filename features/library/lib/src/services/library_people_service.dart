import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_person.dart';

/// Finds borrowers in the ERP (Node); the Library keeps no list of its own.
@lazySingleton
class LibraryPeopleService {
  LibraryPeopleService(this._routes);

  final RouteService _routes;

  /// The student by admission number or RFID, or staff member by ERP ID, or null.
  Future<LibraryPerson?> findByIdentifier(
    String memberType,
    String identifier,
  ) async {
    final number = identifier.trim();
    if (memberType == 'teacher') {
      final staffId = int.tryParse(number);
      if (staffId == null || staffId <= 0) return null;
      return LibraryPerson(
        memberType: 'teacher',
        personErpId: staffId,
        name: 'Staff #$staffId',
        detail: 'Staff ID $staffId',
      );
    }
    final student = await _routes.findStudentByAdmissionNumberOrRfid(number);
    if (student == null) return null;
    return personFrom(student);
  }

  Future<List<Standards>>? _classes;

  /// Classes with their sections, fetched from Node once per session; callers
  /// that ask while it is loading share the same request. A failure is not cached.
  Future<List<Standards>> classes() =>
      _classes ??= _routes.getStandards().onError<Object>((error, stack) {
        _classes = null;
        Error.throwWithStackTrace(error, stack);
      });

  /// Forgets cached ERP data; call when the signed-in user or branch changes.
  void clearCache() => _classes = null;

  /// Every student of [classId] in [sections], following Node's pages.
  Future<List<StudentData>> studentsOf(
    int classId,
    List<String> sections,
  ) async {
    final students = <StudentData>[];
    for (var page = 1; ; page++) {
      final result = await _routes.getStudents(
        classId: classId,
        sections: sections,
        pageNo: page,
      );
      students.addAll(result.data);
      final total = result.metadata.isEmpty ? 0 : result.metadata.first.total;
      if (result.data.isEmpty || students.length >= total) return students;
    }
  }

  LibraryPerson personFrom(StudentData student) => LibraryPerson(
    memberType: 'student',
    personErpId: student.id,
    name: student.name,
    classId: student.classId == 0 ? null : student.classId,
    section: student.section,
    admissionNumber: student.admissionNumber,
    photoUrl: student.photoUrl,
    detail: [
      if (student.standard.isNotEmpty)
        '${student.standard.toLowerCase().startsWith('class') ? '' : 'Class '}${student.standard}${student.section.isEmpty ? '' : ' (${student.section})'}',
      if (student.admissionNumber.isNotEmpty) 'Adm. ${student.admissionNumber}',
    ].join(' · '),
  );
}
