import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/src/import/book_import.dart';
import 'package:school_library/src/import/spreadsheet.dart';

const _lookups = BookImportLookups(
  categoryIds: {
    'biography': 'c1',
    'fiction': 'c3',
    'science > physics': 'c2',
    'shared': null,
  },
  libraryIds: {'central library': 'l1', 'junior library': 'l2'},
  classIds: {'class 6': 6, 'class 8': 8, 'class 9': 9},
);

final _header = [for (final column in bookImportColumns) column.header];

/// A copy row: valid defaults overridden by [cells], every other column empty.
List<String> _row(Map<String, String> cells) => [
  for (final column in bookImportColumns)
    {
          'barcode': 'A1',
          'title': 'T',
          'authors': 'A',
          'category': 'Biography',
          'library': 'Central Library',
          ...cells,
        }[column.key] ??
        '',
];

BookImportPlan _plan(List<List<String>> rows) =>
    planBookImport([_header, ...rows], _lookups);

void main() {
  test('the template reads back from CSV and Excel and imports cleanly', () {
    final csvRows = readSheetRows(
      'template.csv',
      utf8.encode(bookImportTemplateCsv()),
    );
    final xlsxRows = readSheetRows('template.xlsx', bookImportTemplateXlsx());
    expect(xlsxRows.first, csvRows.first);
    expect(xlsxRows[1], csvRows[1]);

    final plan = planBookImport(csvRows, _lookups);
    expect(plan.issues.map((issue) => issue.errors), isEmpty);
    expect(plan.books, hasLength(2));
    expect(plan.books.first.copies.map((copy) => copy.barcode), [
      'ACC-0001',
      'ACC-0002',
    ]);
  });

  test('copy rows are grouped into books, split by library and shelf', () {
    final wings = {
      'title': 'Wings of Fire',
      'authors': 'Kalam; Tiwari',
      'year': '1999',
    };
    final plan = _plan([
      _row({
        ...wings,
        'barcode': 'A1',
        'shelf': 'B-1',
        'price': '250',
        'acquiredDate': '31/03/2024',
      }),
      _row({
        ...wings,
        'barcode': 'A2',
        'title': 'wings  of fire',
        'authors': 'KALAM',
        'shelf': 'B-1',
        'price': '250',
        'acquiredDate': '31/03/2024',
      }),
      _row({...wings, 'barcode': 'A3', 'library': 'Junior Library'}),
      _row({...wings, 'barcode': 'A4', 'year': '2005'}),
      List.filled(_header.length, ''),
    ]);
    expect(plan.issues, isEmpty);
    expect(
      plan.books,
      hasLength(2),
    ); // 1999 and 2005 editions are different titles
    final first = plan.books.first;
    expect(first.copies, hasLength(3));
    expect(first.book['authors'], ['Kalam', 'Tiwari']);
    final batches = first.copyBatches;
    expect(batches, hasLength(2)); // one call per library
    expect(batches.first['barcodes'], ['A1', 'A2']);
    expect(batches.first['quantity'], 2);
    final details = batches.first['details']! as List<Map<String, Object?>>;
    expect(details.first, {
      'shelf': 'B-1',
      'condition': 'good',
      'price': 250.0,
      'date': '2024-03-31',
    });
    expect(batches.last['libraryId'], 'l2');
    final junior =
        (batches.last['details']! as List<Map<String, Object?>>).single;
    expect(junior.containsKey('date'), isFalse);
    expect(junior['shelf'], isNull);
  });

  test(
    'bad rows are reported and left out; good rows of the same book stay',
    () {
      final plan = _plan([
        _row({'barcode': 'A1'}),
        _row({'barcode': 'A1'}),
        _row({'barcode': 'A2', 'category': 'Fiction'}),
        _row({
          'barcode': 'A3',
          'category': 'Nope',
          'library': 'Nowhere',
          'price': 'abc',
          'acquiredDate': '31/02/2024',
        }),
        _row({'barcode': '', 'category': 'Shared'}),
        _row({'barcode': 'LB000123', 'category': 'Science > Physics'}),
      ]);
      expect(plan.books.single.copies.map((copy) => copy.barcode), ['A1']);
      final errors = {
        for (final issue in plan.issues) issue.line: issue.errors.join('|'),
      };
      expect(errors[3], contains('also on row 2'));
      expect(errors[4], contains('Category differs from row 2'));
      expect(
        errors[5],
        allOf(
          contains('Category "Nope"'),
          contains('Library "Nowhere"'),
          contains('Price'),
          contains('Purchase Date'),
        ),
      );
      expect(
        errors[6],
        allOf(contains('Parent > Child'), contains('Barcode is required')),
      );
      expect(errors[7], contains('reserved'));
    },
  );

  test('a call never carries more than 200 copies', () {
    final plan = _plan([
      for (var index = 0; index < 450; index++) _row({'barcode': 'B$index'}),
    ]);
    final batches = plan.books.single.copyBatches;
    expect(batches.map((batch) => batch['quantity']), [200, 200, 50]);
  });

  test('barcodes already in the system become issues', () {
    final plan = _plan([
      _row({'barcode': 'A1'}),
      _row({'barcode': 'A2'}),
    ]).withTakenBarcodes({'A2'});
    expect(plan.issues, hasLength(1));
    expect(plan.issues.single.line, 3);
    expect(plan.issues.single.errors.single, contains('already exists'));
  });

  test('dates in the common school formats', () {
    expect(parseImportDate('31/03/2024'), '2024-03-31');
    expect(parseImportDate('1-4-2024'), '2024-04-01');
    expect(parseImportDate('2024-03-31'), '2024-03-31');
    expect(parseImportDate('45382'), '2024-03-31'); // Excel day number
    expect(parseImportDate('31/02/2024'), isNull);
    expect(parseImportDate('soon'), isNull);
  });

  test('only a sheet that follows the template is accepted', () {
    expect(
      () => planBookImport([_header.take(3).toList()], _lookups),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('Missing columns'), contains('template')),
        ),
      ),
    );
    expect(
      () => planBookImport([
        [..._header, 'Remarks'],
      ], _lookups),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unknown columns: Remarks'),
        ),
      ),
    );
    expect(() => planBookImport([], _lookups), throwsFormatException);
    // The template's own header (with * marks) and column order do not matter.
    expect(
      planBookImport([
        bookImportTemplateRows().first.reversed.toList(),
      ], _lookups).books,
      isEmpty,
    );
  });
}
