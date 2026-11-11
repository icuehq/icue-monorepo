import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/src/import/spreadsheet.dart';

/// One column of the import sheet. A row is one physical copy.
class BookImportColumn {
  const BookImportColumn(
    this.key,
    this.header,
    this.help,
    this.example, {
    this.required = false,
  });

  final String key;
  final String header;
  final String help;
  final String example;
  final bool required;

  /// Headers match ignoring case, spaces and punctuation, so `Title *` and `title` are the same.
  static String normalize(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool matches(String name) => normalize(name) == normalize(header);
}

const bookImportColumns = [
  BookImportColumn(
    'barcode',
    'Barcode',
    'The copy\'s barcode / accession number. Different on every row.',
    'ACC-0001',
    required: true,
  ),
  BookImportColumn(
    'title',
    'Title',
    'Book title, up to 200 characters.',
    'Wings of Fire',
    required: true,
  ),
  BookImportColumn(
    'authors',
    'Authors',
    'One to 10 authors; separate several with a semicolon (;).',
    'A. P. J. Abdul Kalam; Arun Tiwari',
    required: true,
  ),
  BookImportColumn(
    'category',
    'Category',
    'Name of a Library category. For a subcategory write Parent > Child.',
    'Biography',
    required: true,
  ),
  BookImportColumn(
    'library',
    'Library',
    'Name of the library holding this copy.',
    'Central Library',
    required: true,
  ),
  BookImportColumn(
    'shelf',
    'Shelf',
    'Shelf or rack of the copy. Optional.',
    'B-12',
  ),
  BookImportColumn(
    'condition',
    'Condition',
    'good, fair or poor. Empty means good.',
    'good',
  ),
  BookImportColumn(
    'price',
    'Price',
    'Price paid for the copy, in rupees. Optional.',
    '250',
  ),
  BookImportColumn(
    'acquiredDate',
    'Purchase Date',
    'Date the copy was purchased, as 31/03/2024 or 2024-03-31. Empty means today.',
    '31/03/2024',
  ),
  BookImportColumn(
    'subtitle',
    'Subtitle',
    'Optional. Taken from the first row of the book.',
    'An Autobiography',
  ),
  BookImportColumn('publisher', 'Publisher', 'Optional.', 'Universities Press'),
  BookImportColumn('edition', 'Edition', 'Optional.', '1st'),
  BookImportColumn(
    'year',
    'Year',
    'Publication year, four digits. Optional.',
    '1999',
  ),
  BookImportColumn('language', 'Language', 'Optional.', 'English'),
  BookImportColumn('pages', 'Pages', 'Number of pages. Optional.', '180'),
  BookImportColumn(
    'classes',
    'Classes',
    'Class names exactly as in the ERP, separated by ;. Empty means a book for any class.',
    'Class 8; Class 9',
  ),
  BookImportColumn(
    'keywords',
    'Keywords',
    'Search words separated by ;. Optional.',
    'autobiography; science',
  ),
];

/// Most copies one `library-book-create` call takes.
const bookImportCallLimit = 200;

/// Most data rows (copies) one import takes.
const bookImportMaxRows = 5000;

/// One checked copy row.
class BookImportCopy {
  const BookImportCopy({
    required this.line,
    required this.barcode,
    required this.libraryId,
    required this.shelf,
    required this.condition,
    required this.price,
    required this.date,
  });

  /// Row number in the sheet (the header is row 1).
  final int line;
  final String barcode;
  final String libraryId;
  final String? shelf;
  final String condition;
  final double price;
  final String? date;
}

/// A title and the copies the sheet lists for it (rows with the same title, first author,
/// edition, publisher and year).
class BookImportBook {
  BookImportBook({
    required this.firstLine,
    required this.title,
    required this.book,
    required this.categoryId,
  });

  final int firstLine;
  final String title;
  final String categoryId;

  /// The fields `LibraryWrites.saveBook` takes.
  final Map<String, Object?> book;
  final copies = <BookImportCopy>[];

  /// The `library-book-create` inputs (without `catalogueId`): one per library, at most
  /// [bookImportCallLimit] copies each, with every copy's own shelf, condition, price and date.
  List<Map<String, Object?>> get copyBatches {
    final byLibrary = <String, List<BookImportCopy>>{};
    for (final copy in copies) {
      byLibrary.putIfAbsent(copy.libraryId, () => []).add(copy);
    }
    return [
      for (final group in byLibrary.values)
        for (var start = 0; start < group.length; start += bookImportCallLimit)
          () {
            final part = group.skip(start).take(bookImportCallLimit).toList();
            return <String, Object?>{
              'libraryId': part.first.libraryId,
              'quantity': part.length,
              'barcodes': [for (final copy in part) copy.barcode],
              'details': [
                for (final copy in part)
                  {
                    'shelf': copy.shelf,
                    'condition': copy.condition,
                    'price': copy.price,
                    'date': ?copy.date,
                  },
              ],
            };
          }(),
    ];
  }
}

/// A row that cannot be imported, with why.
class BookImportIssue {
  const BookImportIssue(this.line, this.title, this.errors);

  final int line;
  final String title;
  final List<String> errors;
}

class BookImportPlan {
  const BookImportPlan(this.books, this.issues);

  final List<BookImportBook> books;
  final List<BookImportIssue> issues;

  /// This plan with an issue for every copy whose barcode is in [taken].
  BookImportPlan withTakenBarcodes(Set<String> taken) => BookImportPlan(
    books,
    [
      ...issues,
      for (final book in books)
        for (final copy in book.copies)
          if (taken.contains(copy.barcode))
            BookImportIssue(copy.line, book.title, [
              'Barcode "${copy.barcode}" already exists in the system',
            ]),
    ]..sort((first, second) => first.line.compareTo(second.line)),
  );

  int get copyCount => books.fold(0, (sum, book) => sum + book.copies.length);
}

/// The Library's lists a sheet refers to by name.
class BookImportLookups {
  const BookImportLookups({
    required this.categoryIds,
    required this.libraryIds,
    required this.classIds,
  });

  /// Lower-case category name (or `parent > child`) to ID; null when two categories share the name.
  final Map<String, String?> categoryIds;
  final Map<String, String> libraryIds;
  final Map<String, int> classIds;
}

List<String> _list(String value) => [
  for (final part in value.split(';'))
    if (part.trim().isNotEmpty) part.trim(),
];

String _words(String value) => value
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((word) => word.isNotEmpty)
    .join(' ');

/// `yyyy-MM-dd` of a date typed as `31/03/2024`, `31-03-2024`, `2024-03-31` or an Excel day
/// number; null when it is none of those or not a real day.
String? parseImportDate(String text) {
  DateTime? date;
  final dayFirst = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$')
      .firstMatch(text);
  final yearFirst = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
  int part(RegExpMatch match, int group) => int.parse(match.group(group)!);
  if (dayFirst != null) {
    date = DateTime.utc(
      part(dayFirst, 3),
      part(dayFirst, 2),
      part(dayFirst, 1),
    );
    if (date.day != part(dayFirst, 1)) return null;
  } else if (yearFirst != null) {
    date = DateTime.utc(
      part(yearFirst, 1),
      part(yearFirst, 2),
      part(yearFirst, 3),
    );
    if (date.day != part(yearFirst, 3)) return null;
  } else if (RegExp(r'^\d{5}$').hasMatch(text)) {
    date = DateTime.utc(1899, 12, 30).add(Duration(days: int.parse(text)));
  }
  if (date == null) return null;
  final month = '${date.month}'.padLeft(2, '0');
  final day = '${date.day}'.padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Reads [rows] (header first), one copy per row, and groups them into books. Throws
/// [FormatException] when the sheet has no header, misses a required column or is too long.
BookImportPlan planBookImport(
  List<List<String>> rows,
  BookImportLookups lookups,
) {
  if (rows.isEmpty) throw const FormatException('The file is empty');
  int? columnOf(BookImportColumn column) {
    for (var index = 0; index < rows.first.length; index++) {
      if (column.matches(rows.first[index])) return index;
    }
    return null;
  }

  final indexes = {
    for (final column in bookImportColumns) column.key: columnOf(column),
  };
  final headers = [for (final header in rows.first) header.trim()];
  final unknown = [
    for (final header in headers)
      if (header.isNotEmpty &&
          !bookImportColumns.any((column) => column.matches(header)))
        header,
  ];
  final missing = [
    for (final column in bookImportColumns)
      if (indexes[column.key] == null) column.header,
  ];
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException(
      'This file does not follow the template. '
      '${missing.isEmpty ? '' : 'Missing columns: ${missing.join(', ')}. '}'
      '${unknown.isEmpty ? '' : 'Unknown columns: ${unknown.join(', ')}. '}'
      'Download the template and enter the data in it.',
    );
  }
  final dataRows = [
    for (var index = 1; index < rows.length; index++)
      if (rows[index].any((cell) => cell.trim().isNotEmpty)) index,
  ];
  if (dataRows.length > bookImportMaxRows) {
    throw const FormatException(
      'Import at most $bookImportMaxRows copies at a time',
    );
  }

  final books = <String, BookImportBook>{};
  final barcodeLines = <String, int>{};
  final issues = <BookImportIssue>[];
  for (final index in dataRows) {
    String value(String key) {
      final column = indexes[key];
      return column == null || column >= rows[index].length
          ? ''
          : rows[index][column].trim();
    }

    final errors = <String>[];
    final line = index + 1;
    final title = value('title');
    if (title.isEmpty || title.length > 200) {
      errors.add('Title must be 1 to 200 characters');
    }
    final authors = _list(value('authors'));
    if (authors.isEmpty || authors.length > 10) {
      errors.add('Enter 1 to 10 authors');
    }

    final categoryName = value('category')
        .toLowerCase()
        .replaceAll(RegExp(r'\s*>\s*'), ' > ');
    String? categoryId;
    if (categoryName.isEmpty) {
      errors.add('Category is required');
    } else if (!lookups.categoryIds.containsKey(categoryName)) {
      errors.add('Category "${value('category')}" not found');
    } else {
      categoryId = lookups.categoryIds[categoryName];
      if (categoryId == null) {
        errors.add(
          'Category "${value('category')}" exists under more than one parent; write Parent > Child',
        );
      }
    }

    int? whole(String key, int min, int max) {
      final text = value(key);
      if (text.isEmpty) return null;
      final parsed = int.tryParse(text);
      if (parsed == null || parsed < min || parsed > max) {
        errors.add('${_header(key)} must be a number from $min to $max');
        return null;
      }
      return parsed;
    }

    final year = whole('year', 1000, 2999);
    final pages = whole('pages', 1, 100000);

    final classIds = <int>{};
    for (final name in _list(value('classes'))) {
      final id = lookups.classIds[name.toLowerCase()];
      if (id == null) {
        errors.add('Class "$name" not found');
      } else {
        classIds.add(id);
      }
    }

    final barcode = value('barcode');
    if (barcode.isEmpty) {
      errors.add('Barcode is required');
    } else if (barcode.length > 64 || barcode.contains('/')) {
      errors.add('Barcode must be up to 64 characters without /');
    } else if (RegExp(r'^LB\d{6,}$', caseSensitive: false).hasMatch(barcode)) {
      errors.add('Barcode "$barcode" is reserved for system-issued codes');
    } else {
      final earlier = barcodeLines[barcode.toLowerCase()];
      if (earlier != null) {
        errors.add('Barcode "$barcode" is also on row $earlier');
      }
    }

    final libraryId = lookups.libraryIds[value('library').toLowerCase()];
    if (value('library').isEmpty) {
      errors.add('Library is required');
    } else if (libraryId == null) {
      errors.add('Library "${value('library')}" not found');
    }

    final condition = value('condition').isEmpty
        ? 'good'
        : value('condition').toLowerCase();
    if (!const ['good', 'fair', 'poor'].contains(condition)) {
      errors.add('Condition must be good, fair or poor');
    }
    final priceText = value('price').replaceAll(RegExp(r'[₹,\s]'), '');
    final price = priceText.isEmpty ? 0.0 : double.tryParse(priceText);
    if (price == null || price < 0 || price > 10000000) {
      errors.add('Price must be a number from 0 to 10000000');
    }
    final dateText = value('acquiredDate');
    final date = dateText.isEmpty ? null : parseImportDate(dateText);
    if (dateText.isNotEmpty && date == null) {
      errors.add('Purchase Date "$dateText" is not a date; use 31/03/2024');
    }

    final identity = [
      title,
      authors.firstOrNull ?? '',
      value('edition'),
      value('publisher'),
      '${year ?? ''}',
    ].map(_words).join('|');
    final existing = books[identity];
    if (existing != null &&
        categoryId != null &&
        existing.categoryId != categoryId) {
      errors.add('Category differs from row ${existing.firstLine} (same book)');
    }

    if (errors.isNotEmpty) {
      issues.add(BookImportIssue(line, title, errors));
      continue;
    }
    barcodeLines[barcode.toLowerCase()] = line;
    String? orNull(String key) => value(key).isEmpty ? null : value(key);
    final group = books.putIfAbsent(
      identity,
      () => BookImportBook(
        firstLine: line,
        title: title,
        categoryId: categoryId!,
        book: {
          'title': title,
          'subtitle': orNull('subtitle'),
          'authors': authors,
          'publisher': orNull('publisher'),
          'edition': orNull('edition'),
          'year': year,
          'language': orNull('language'),
          'categoryId': categoryId,
          'classIds': classIds.toList(),
          'description': null,
          'pages': pages,
          'shelf': null,
          'keywords': _list(value('keywords')),
        },
      ),
    );
    group.copies.add(
      BookImportCopy(
        line: line,
        barcode: barcode,
        libraryId: libraryId!,
        shelf: orNull('shelf'),
        condition: condition,
        price: price!,
        date: date,
      ),
    );
  }
  return BookImportPlan(books.values.toList(), issues);
}

String _header(String key) =>
    bookImportColumns.firstWhere((column) => column.key == key).header;

/// The empty import sheet: a header and example rows (the first two are copies of one book).
List<List<String>> bookImportTemplateRows() => [
  [
    for (final column in bookImportColumns)
      column.required ? '${column.header} *' : column.header,
  ],
  [for (final column in bookImportColumns) column.example],
  [
    for (final column in bookImportColumns)
      column.key == 'barcode' ? 'ACC-0002' : column.example,
  ],
  [
    for (final column in bookImportColumns)
      switch (column.key) {
        'barcode' => 'ACC-0003',
        'title' => 'Malgudi Days',
        'authors' => 'R. K. Narayan',
        'category' => 'Fiction',
        'condition' => 'fair',
        'price' => '180',
        'subtitle' => '',
        'publisher' => 'Indian Thought',
        'edition' => '',
        'year' => '1982',
        'pages' => '240',
        'classes' => 'Class 6',
        'keywords' => 'stories',
        _ => column.example,
      },
  ],
];

/// What each column takes, for the Instructions sheet.
List<List<String>> bookImportInstructionRows() => [
  ['Column', 'Required', 'What to enter'],
  for (final column in bookImportColumns)
    [column.header, column.required ? 'Yes' : 'No', column.help],
  [],
  ['Notes'],
  [
    'One row per physical copy. Delete the example rows and keep the header row.',
  ],
  [
    'Rows with the same Title, first Author, Edition, Publisher and Year are one book; its copies are grouped under it.',
  ],
  [
    'A book already in the catalogue gets the new copies added to it. A barcode that already exists is refused.',
  ],
  [
    'The book details (Category, Subtitle, Classes, ...) come from the first row of each book.',
  ],
  ['Import at most $bookImportMaxRows copies per file.'],
];

String bookImportTemplateCsv() {
  final rows = bookImportTemplateRows();
  return toCsv(rows.first, rows.skip(1).toList());
}

List<int> bookImportTemplateXlsx() => buildXlsx({
  'Copies': bookImportTemplateRows(),
  'Instructions': bookImportInstructionRows(),
});
