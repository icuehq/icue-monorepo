import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_person.dart';

/// Finds borrowers in the ERP (Node); the Library keeps no list of its own.
@lazySingleton
class LibraryPeopleService {
  LibraryPeopleService(this._routes);

  final RouteService _routes;

  /// The student by admission number, or staff member by ERP ID, or null.
  Future<LibraryPerson?> findByAdmissionNumber(
    String memberType,
    String admissionNumber,
  ) async {
    final number = admissionNumber.trim();
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
    final student = await _routes.searchStudentByAdmissionNumber(number);
    if (student == null) return null;
    return personFrom(memberType, student);
  }

  /// Classes with their sections, for picking a student from a class list.
  Future<List<Standards>> classes() => _routes.getStandards();

  /// Every student of [classId] in [section], following Node's pages.
  Future<List<StudentData>> studentsOf(int classId, String section) async {
    final students = <StudentData>[];
    for (var page = 1; ; page++) {
      final result = await _routes.getStudents(
        classId: classId,
        sections: [section],
        pageNo: page,
      );
      students.addAll(result.data);
      final total = result.metadata.isEmpty ? 0 : result.metadata.first.total;
      if (result.data.isEmpty || students.length >= total) return students;
    }
  }

  LibraryPerson personFrom(
    String memberType,
    StudentData student,
  ) => LibraryPerson(
    memberType: memberType,
    personErpId: student.id,
    name: student.name,
    classId: student.classId == 0 ? null : student.classId,
    detail: [
      if (memberType == 'student' && student.standard.isNotEmpty)
        'Class ${student.standard}${student.section.isEmpty ? '' : ' ${student.section}'}',
      if (student.admissionNumber.isNotEmpty) 'Adm. ${student.admissionNumber}',
    ].join(' · '),
  );
}
