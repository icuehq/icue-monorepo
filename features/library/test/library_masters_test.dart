import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryBook parses a Firestore map and a search row', () {
    final full = LibraryBook.fromMap('b1', {
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

    final row = LibraryBook.fromMap('b2', {'title': 'T', 'authors': null});
    expect(row.authors, isEmpty);
    expect(row.keywords, isEmpty);
    expect(row.active, isTrue);
  });

  test('SchoolLibrary parses contact details and joins them on one line', () {
    final schoolLibrary = SchoolLibrary.fromMap('l1', {
      'name': 'Main',
      'campusId': 31,
      'phone': '+91 98765 43210',
      'email': 'library@school.edu',
    });
    expect(schoolLibrary.contactLine, '+91 98765 43210 · library@school.edu');
    expect(
      SchoolLibrary.fromMap('l2', {
        'name': 'Junior',
        'campusId': 31,
      }).contactLine,
      isEmpty,
    );
  });
}
