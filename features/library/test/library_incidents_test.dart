import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryIncident parses incident document and determines labels and resolution', () {
    final incident = LibraryIncident.fromMap('inc1', {
      'incidentNumber': 'INC/2026-27/000001',
      'type': 'damaged',
      'barcode': 'ACC-000001',
      'catalogueId': 'b1',
      'libraryId': 'lib1',
      'status': 'open',
      'reportedDate': dayTimestamp('2026-11-01'),
      'personErpId': 101,
      'memberType': 'teacher',
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
