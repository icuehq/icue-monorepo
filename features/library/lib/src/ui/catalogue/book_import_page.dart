import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/import/book_import.dart';
import 'package:school_library/src/import/spreadsheet.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_rows.dart';

/// Adds many books (and their copies) from a filled-in CSV or Excel template.
class BookImportPage extends StatefulWidget {
  const BookImportPage({super.key});

  @override
  State<BookImportPage> createState() => _BookImportPageState();
}

class _BookImportPageState extends State<BookImportPage> {
  String? _fileName;
  String? _problem;
  BookImportPlan? _plan;
  bool _importing = false;
  bool _finished = false;
  final _results = <int, BookImportResult>{};

  Future<void> _download(String label) async {
    final saved = label == 'xlsx'
        ? await saveFileBytes(
            'books-import-template.xlsx',
            bookImportTemplateXlsx(),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        : await saveCsvFile(
            'books-import-template.csv',
            bookImportTemplateCsv(),
          );
    if (saved && mounted) _toast('Template downloaded');
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );

  Future<void> _choose() async {
    final libraryProvider = context.read<LibraryProvider>();
    final file = await pickSpreadsheet();
    if (file == null) return;
    if (libraryProvider.libraries.isEmpty ||
        libraryProvider.categories.isEmpty) {
      await libraryProvider.loadMasters();
    }
    await libraryProvider.loadStandards();
    try {
      var plan = planBookImport(
        readSheetRows(file.name, file.bytes),
        _lookups(libraryProvider),
      );
      // Every check runs now, before anything is written.
      plan = plan.withTakenBarcodes(
        await libraryProvider.existingBarcodes([
          for (final book in plan.books)
            for (final copy in book.copies) copy.barcode,
        ]),
      );
      setState(() {
        _fileName = file.name;
        _plan = plan;
        _problem = plan.books.isEmpty && plan.issues.isEmpty
            ? 'The file has no rows'
            : null;
        _results.clear();
        _finished = false;
      });
    } on FormatException catch (error) {
      setState(() {
        _fileName = file.name;
        _plan = null;
        _problem = error.message;
      });
    } on Object catch (error) {
      setState(() {
        _fileName = file.name;
        _plan = null;
        _problem = 'Could not check the file: ${callableErrorMessage(error)}';
      });
    }
  }

  BookImportLookups _lookups(LibraryProvider libraryProvider) {
    final categoryIds = <String, String?>{};
    void add(String name, String id) => categoryIds[name.toLowerCase()] =
        categoryIds.containsKey(name.toLowerCase()) ? null : id;
    for (final category in libraryProvider.categories.where(
      (category) => category.active,
    )) {
      add(category.name, category.id);
      final parent = libraryProvider.category(category.parentId);
      if (parent != null) add('${parent.name} > ${category.name}', category.id);
    }
    return BookImportLookups(
      categoryIds: categoryIds,
      libraryIds: {
        for (final library in libraryProvider.libraries.where(
          (library) => library.active,
        ))
          library.name.toLowerCase(): library.id,
      },
      classIds: {
        for (final standard in libraryProvider.standards)
          standard.name.toLowerCase(): standard.id,
      },
    );
  }

  Future<void> _import() async {
    final libraryProvider = context.read<LibraryProvider>();
    final importId = newRequestId();
    setState(() {
      _importing = true;
      _results.clear();
    });
    for (final book in _plan!.books) {
      final result = await libraryProvider.importBook(
        book.book,
        book.copyBatches,
        '$importId-${book.firstLine}',
      );
      if (!mounted) return;
      setState(() => _results[book.firstLine] = result);
    }
    await libraryProvider.loadBooks();
    if (mounted) {
      setState(() {
        _importing = false;
        _finished = true;
      });
    }
  }

  int get _copiesAdded =>
      _results.values.fold(0, (total, result) => total + result.copiesAdded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final failed = _results.values
        .where((result) => result.error != null)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Import books')),
      body: IcueCenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IcueFormSectionCard(
              title: '1. Get the template',
              icon: Icons.download_rounded,
              children: [
                const Text(
                  'Enter the data in our template only; files with other columns are refused. One row per physical copy, with its barcode. Copies of the same '
                  'book (same title, first author, edition, publisher and year) are '
                  'grouped automatically, and copies of a book already in the '
                  'catalogue are added to it. The Instructions sheet of the Excel '
                  'template explains each column; delete the example rows first.',
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    IcueButton(
                      label: 'Excel template (.xlsx)',
                      leadingIcon: Icons.table_chart_outlined,
                      variant: IcueButtonVariant.outline,
                      onPressed: () => _download('xlsx'),
                    ),
                    IcueButton(
                      label: 'CSV template (.csv)',
                      leadingIcon: Icons.description_outlined,
                      variant: IcueButtonVariant.outline,
                      onPressed: () => _download('csv'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            IcueFormSectionCard(
              title: '2. Upload the filled file',
              icon: Icons.upload_file_rounded,
              children: [
                IcueButton(
                  label: _fileName ?? 'Choose .xlsx or .csv file',
                  leadingIcon: Icons.attach_file_rounded,
                  variant: IcueButtonVariant.outline,
                  onPressed: _importing ? null : _choose,
                ),
                if (_problem != null)
                  Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
            ),
            if (plan != null &&
                (plan.books.isNotEmpty || plan.issues.isNotEmpty)) ...[
              const SizedBox(height: 16),
              IcueFormSectionCard(
                title: '3. Review and import',
                icon: Icons.fact_check_outlined,
                children: [
                  Text(
                    _finished
                        ? '$_copiesAdded copies added to ${_results.length - failed} books, '
                              '$failed books stopped with an error'
                        : plan.issues.isEmpty
                        ? '${plan.books.length} books with ${plan.copyCount} copies are ready to import.'
                        : '${plan.issues.length} rows have errors. Nothing is imported '
                              'until the whole file is valid: fix them in the file and upload it again.',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (!_finished && plan.issues.isEmpty)
                    IcueButton(
                      label:
                          'Import ${plan.copyCount} copies of ${plan.books.length} books',
                      leadingIcon: Icons.playlist_add_rounded,
                      isLoading: _importing,
                      onPressed: plan.books.isEmpty || _importing
                          ? null
                          : _import,
                    ),
                  if (_importing)
                    LinearProgressIndicator(
                      value: _results.length / plan.books.length,
                    ),
                  for (final issue in plan.issues)
                    BookImportIssueTile(issue: issue),
                  if (plan.issues.isEmpty && plan.books.isNotEmpty)
                    SizedBox(
                      height: 420,
                      child: ListView.builder(
                        itemCount: plan.books.length,
                        itemBuilder: (context, index) => BookImportBookTile(
                          book: plan.books[index],
                          result: _results[plan.books[index].firstLine],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
