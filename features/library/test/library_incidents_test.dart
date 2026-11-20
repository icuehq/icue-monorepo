import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryIncident parses incident document and determines labels and resolution', () {
    final incident = LibraryIncident.fromMap('inc1', {
      'type': 'damaged',
      'barcode': 'ACC-000001',
      'catalogueId': 'b1',
      'libraryId': 'lib1',
      'status': 'open',
      'reportedDate': dayTimestamp('2026-11-01'),
      'personErpId': 101,
      'memberType': 'EMPLOYEE',
      'severity': 'moderate',
      'description': 'Water damaged back cover',
      'charge': 100.0,
      'repairStatus': 'none',
    });

    expect(incident.isOpen, isTrue);
    expect(incident.memberLabel, 'Employee #101');
    expect(incident.charge, 100.0);
    expect(incidentResolutionLabel('repaired'), 'Repaired');
  });
}
