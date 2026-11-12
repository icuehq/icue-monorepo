import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  const names = LibraryNames(title: _name, library: _name);
  String cells(String key, Map<String, dynamic> row) => libraryReports
      .firstWhere((reportDef) => reportDef.key == key)
      .cols
      .map((reportColumn) => reportColumn.cell(row, names))
      .join('|');

  test('date range, monthly, student and staff reports exist', () {
    expect(libraryReports.map((reportDef) => reportDef.key), [
      'dateRange',
      'monthly',
      'student',
      'staff',
    ]);
  });

  test('monthly row shows the month name and both counts', () {
    expect(
      cells('monthly', {'month': '2026-11', 'issued': 4, 'returned': 2}),
      'Nov 2026|4|2',
    );
  });

  test('member row shows name with ERP ID and the counts', () {
    expect(
      cells('student', {
        'memberName': 'Asha',
        'personErpId': 501,
        'issued': 3,
        'returned': 2,
        'active': 1,
        'overdue': 1,
      }),
      'Asha (#501)|3|2|1|1',
    );
  });

  test('loan row shows names for IDs and the days', () {
    final row = cells('dateRange', {
      'id': 'loan1',
      'memberName': 'Asha',
      'personErpId': 501,
      'catalogueId': 'T',
      'barcode': 'B1',
      'libraryId': 'L',
      'issuedDate': dayTimestamp('2026-11-01'),
      'status': 'active',
    });
    expect(row, 'loan1|Asha (#501)|name:T|B1|name:L|01/11/2026|||active');
  });
}

String _name(Object? id) => 'name:$id';
