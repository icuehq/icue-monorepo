import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  final names = LibraryNames(
    title: _name,
    library: _name,
    classLabel: (classId, section) => 'Class $classId',
  );
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

  test('member row shows name, class (section), admission and counts', () {
    expect(
      cells('student', {
        'memberName': 'Asha',
        'personErpId': 501,
        'memberClassId': 5,
        'memberSection': 'A',
        'admissionNumber': '1234',
        'issued': 3,
        'returned': 2,
        'active': 1,
        'overdue': 1,
      }),
      'Asha\nClass 5 (A)|1234|3|2|1|1',
    );
  });

  test('staff row has no class and falls back to the ERP ID', () {
    expect(cells('staff', {'personErpId': 77, 'issued': 1}), '#77||1|0|0|0');
  });

  test('loan row shows names for IDs and the days', () {
    final row = cells('dateRange', {
      'memberName': 'Asha',
      'personErpId': 501,
      'catalogueId': 'T',
      'libraryId': 'L',
      'issuedDate': dayTimestamp('2026-11-01'),
      'status': 'active',
    });
    expect(row, 'Asha||name:T|name:L|01/11/2026|||active');
  });

  test('overview figures: branch or one library, overdue from due days before today', () {
    final summary = {
      'copies': 5,
      'titles': 3,
      'dueOn': {'2026-11-12': 2, '2026-11-13': 1, '2026-11-01': 0},
      'libraries': {
        'main': {
          'copies': 2,
          'students': 1,
          'dueOn': {'2026-11-10': 1, '2026-11-20': 1},
        },
      },
    };
    final branch = overviewFigures(summary, null, today: '2026-11-13');
    expect([branch['copies'], branch['titles'], branch['overdue']], [5, 3, 2]);
    final main = overviewFigures(summary, 'main', today: '2026-11-13');
    expect([main['copies'], main['students'], main['overdue']], [2, 1, 1]);
    expect(overviewFigures(null, 'other', today: '2026-11-13')['copies'], 0);
  });
}

String _name(Object? id) => 'name:$id';
