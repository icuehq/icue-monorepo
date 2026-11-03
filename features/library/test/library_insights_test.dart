import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  const names = LibraryNames(title: _name, library: _name, category: _name);
  String cells(String key, Map<String, dynamic> row) => libraryReports
      .firstWhere((reportDef) => reportDef.key == key)
      .cols
      .map((reportColumn) => reportColumn.cell(row, names))
      .join('|');

  test('every FRS 11.18 report is defined once', () {
    expect(libraryReports.map((reportDef) => reportDef.key).toSet().length, 15);
  });

  test('overdue report counts days past the due date, never negative', () {
    String ago(int d) => DateTime.now()
        .subtract(Duration(days: d))
        .toIso8601String()
        .substring(0, 10);
    final late = cells('overdue', {
      'dueDate': dayTimestamp(ago(3)),
      'catalogueId': 't1',
    });
    expect(late.split('|').last, '3');
    expect(
      cells('overdue', {'dueDate': dayTimestamp(ago(-2))}).split('|').last,
      '0',
    );
  });

  test('cells show names for IDs and the member as type and ERP ID', () {
    final row = cells('history', {
      'number': 'ISS/1',
      'memberType': 'student',
      'personErpId': 501,
      'catalogueId': 'T',
      'issuedDate': dayTimestamp('2026-11-01'),
      'status': 'active',
    });
    expect(row, 'ISS/1|student #501|name:T|01/11/2026|||active');
  });
}

String _name(Object? id) => 'name:$id';
