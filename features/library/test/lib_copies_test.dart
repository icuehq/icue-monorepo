import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibCopy parses a document and gates manual status changes', () {
    final c = LibCopy.fromMap('ACC-000001', {
      'catalogueId': 'b1',
      'libraryId': 'l1',
      'campusId': 31,
      'price': 250,
      'status': 'available',
    });
    expect(c.accessionNo, 'ACC-000001');
    expect(c.price, 250.0);
    expect(c.condition, 'good');
    expect(c.canChangeStatus, isTrue);
    for (final s in ['issued', 'reserved', 'in_transit', 'lost', 'withdrawn']) {
      expect(
        LibCopy.fromMap('x', {'status': s}).canChangeStatus,
        isFalse,
        reason: s,
      );
    }
    expect(copyStatusLabel('under_maintenance'), 'Under maintenance');
  });
}
