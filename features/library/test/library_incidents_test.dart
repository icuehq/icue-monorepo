import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryIncident parses incident document and determines labels and resolution', () {
    final incident = LibraryIncident.fromMap('inc1', {
      'incidentNumber': 'INC/2026-27/000001',
      'type': 'damaged',
      'copyId': 'ACC-000001',
      'accessionNumber': 'ACC-000001',
      'catalogueId': 'b1',
      'libraryId': 'lib1',
      'campusId': 31,
      'status': 'open',
      'reportedDate': '2026-11-01',
      'memberId': 'teacher_101',
      'memberType': 'teacher',
      'personErpId': 101,
      'severity': 'moderate',
      'description': 'Water damaged back cover',
      'charge': 100.0,
      'repairStatus': 'none',
    });

    expect(incident.incidentNumber, 'INC/2026-27/000001');
    expect(incident.isOpen, isTrue);
    expect(incident.memberLabel, 'Teacher #101');
    expect(incident.charge, 100.0);
    expect(incidentResolutionLabel('repaired'), 'Repaired');
  });
}
