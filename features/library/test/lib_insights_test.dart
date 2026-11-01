import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  const names = LibNames(title: _name, library: _name, category: _name);
  String cells(String key, Map<String, dynamic> row) => libraryReports
      .firstWhere((r) => r.key == key)
      .cols
      .map((c) => c.cell(row, names))
      .join('|');

  test('every FRS 11.18 report is defined once', () {
    expect(libraryReports.map((r) => r.key).toSet().length, 15);
  });

  test('overdue report counts days past the due date, never negative', () {
    String ago(int d) => DateTime.now()
        .subtract(Duration(days: d))
        .toIso8601String()
        .substring(0, 10);
    final late = cells('overdue', {'dueOn': ago(3), 'catalogueId': 't1'});
    expect(late.split('|').last, '3');
    expect(cells('overdue', {'dueOn': ago(-2)}).split('|').last, '0');
  });

  test('cells show names for IDs and the member as type and ERP ID', () {
    final row = cells('history', {
      'number': 'ISS/1',
      'memberType': 'student',
      'personErpId': 501,
      'catalogueId': 'T',
      'issuedOn': '2026-11-01',
      'status': 'active',
    });
    expect(row, 'ISS/1|student #501|name:T|2026-11-01|||active');
  });

  test('libDay reads strings and ignores other values', () {
    expect(libDay('2026-11-01T10:00:00Z'), '2026-11-01');
    expect(libDay(null), '');
  });

  test('LibAccess reads the all-campuses flag', () {
    expect(LibAccess.fromMap({'all': true}).all, isTrue);
    expect(
      LibAccess.fromMap({
        'cmp': [31],
      }).all,
      isFalse,
    );
  });
}

String _name(Object? id) => 'name:$id';
