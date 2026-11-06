import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_person.dart';

/// Finds borrowers in the ERP (Node); the Library keeps no list of its own.
@lazySingleton
class LibraryPeopleService {
  LibraryPeopleService(this._routes);

  final RouteService _routes;

  Future<List<LibraryPerson>> searchStudents(String text) async {
    final students = await _routes.searchStudent(search: text);
    return [
      for (final student in students)
        LibraryPerson(
          memberType: 'student',
          personErpId: student.id,
          name: student.name,
          classId: student.classId == 0 ? null : student.classId,
          detail: [
            if (student.standard.isNotEmpty)
              'Class ${student.standard}${student.section.isEmpty ? '' : ' ${student.section}'}',
            if (student.admissionNumber.isNotEmpty)
              'Adm. ${student.admissionNumber}',
          ].join(' · '),
        ),
    ];
  }

  /// TODO(teachers): call the Node teacher/staff search once its endpoint is known.
  /// Until then teachers cannot be found, so the desk cannot lend to them.
  Future<List<LibraryPerson>> searchTeachers(String text) async => const [];

  /// Whether [searchTeachers] is connected to Node yet.
  bool get teachersAvailable => false;
}
