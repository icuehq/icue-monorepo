import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_person.dart';

/// Finds borrowers in the ERP (Node); the Library keeps no list of its own.
@lazySingleton
class LibraryPeopleService {
  LibraryPeopleService(this._routes);

  final RouteService _routes;

  /// The student or staff member with exactly [admissionNumber] in the ERP (Node), or null.
  Future<LibraryPerson?> findByAdmissionNumber(
    String memberType,
    String admissionNumber,
  ) async {
    final number = admissionNumber.trim().toLowerCase();
    // TODO(staff): call the Node staff lookup by admission number once its endpoint is known.
    if (memberType == 'teacher') {
      throw UnimplementedError('Staff lookup is not connected to Node yet');
    }
    final students = await _routes.searchStudent(search: number);
    for (final student in students) {
      if (student.admissionNumber.toLowerCase() != number) continue;
      return LibraryPerson(
        memberType: 'student',
        personErpId: student.id,
        name: student.name,
        classId: student.classId == 0 ? null : student.classId,
        detail: [
          if (student.standard.isNotEmpty)
            'Class ${student.standard}${student.section.isEmpty ? '' : ' ${student.section}'}',
          'Adm. ${student.admissionNumber}',
        ].join(' · '),
      );
    }
    return null;
  }
}
