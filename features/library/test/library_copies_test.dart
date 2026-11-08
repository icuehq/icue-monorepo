import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryCopy parses a document and gates manual status changes', () {
    final copy = LibraryCopy.fromMap('ACC-000001', {
      'catalogueId': 'b1',
      'libraryId': 'l1',
      'campusId': 31,
      'price': 250,
      'status': 'available',
      'condition': 'good',
    });
    expect(copy.barcode, 'ACC-000001');
    expect(copy.price, 250.0);
    expect(copy.condition, 'good');
    expect(copy.canChangeStatus, isTrue);
    for (final value in [
      'issued',
      'reserved',
      'in_transit',
      'lost',
      'withdrawn',
    ]) {
      expect(
        LibraryCopy.fromMap('x', {'status': value}).canChangeStatus,
        isFalse,
        reason: value,
      );
    }
  });
}
