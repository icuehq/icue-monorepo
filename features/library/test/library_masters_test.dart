import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryBook parses a Firestore map and a search row', () {
    final full = LibraryBook.fromMap('b1', {
      'title': 'Wings of Fire',
      'authors': ['A. P. J. Abdul Kalam', 'Arun Tiwari'],
      'year': 1999,
      'categoryId': 'c1',
      'classIds': [6, 8],
      'keywords': ['autobiography'],
      'status': 'inactive',
    });
    expect(full.authorLine, 'A. P. J. Abdul Kalam, Arun Tiwari');
    expect(full.year, 1999);
    expect(full.keywords, ['autobiography']);
    expect(full.classIds, [6, 8]);
    expect(full.active, isFalse);

    final row = LibraryBook.fromMap('b2', {'title': 'T', 'authors': null});
    expect(row.authors, isEmpty);
    expect(row.keywords, isEmpty);
    expect(row.classIds, isEmpty); // a general book
    expect(row.active, isTrue);
  });
}
