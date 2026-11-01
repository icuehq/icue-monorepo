import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibBook parses a Firestore map and a search row', () {
    final full = LibBook.fromMap('b1', {
      'title': 'Wings of Fire',
      'authors': ['A. P. J. Abdul Kalam', 'Arun Tiwari'],
      'isbn13': '9788173711466',
      'year': 1999,
      'categoryId': 'c1',
      'keywords': ['autobiography'],
      'status': 'inactive',
    });
    expect(full.authorLine, 'A. P. J. Abdul Kalam, Arun Tiwari');
    expect(full.year, 1999);
    expect(full.keywords, ['autobiography']);
    expect(full.active, isFalse);

    final row = LibBook.fromMap('b2', {'title': 'T', 'authors': null});
    expect(row.authors, isEmpty);
    expect(row.keywords, isEmpty);
    expect(row.active, isTrue);
  });

  test('LibLibrary parses staff ids; LibAccess answers permission checks', () {
    final l = LibLibrary.fromMap('l1', {
      'code': 'MAIN',
      'name': 'Main',
      'campusId': 31,
      'staffIds': [5, 6],
    });
    expect(l.staffIds, [5, 6]);
    expect(
      LibAccess.fromMap({
        'perms': ['lib.settings'],
      }).can('lib.settings'),
      isTrue,
    );
    expect(const LibAccess().can('lib.settings'), isFalse);
  });
}
