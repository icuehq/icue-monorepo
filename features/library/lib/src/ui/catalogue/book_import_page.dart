import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/import/book_import.dart';
import 'package:school_library/src/import/spreadsheet.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_issues_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_preview_section.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_summary_cards.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_template_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_upload_card.dart';

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

  Future<void> _download(String format) async {
    final saved = format == 'xlsx'
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

  void _reset() {
    setState(() {
      _fileName = null;
      _problem = null;
      _plan = null;
      _importing = false;
      _finished = false;
      _results.clear();
    });
  }

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
    void addCategory(String name, String id) =>
        categoryIds[name.toLowerCase()] =
            categoryIds.containsKey(name.toLowerCase()) ? null : id;
    for (final category in libraryProvider.categories.where(
      (category) => category.active,
    )) {
      addCategory(category.name, category.id);
      final parent = libraryProvider.category(category.parentId);
      if (parent != null) {
        addCategory('${parent.name} > ${category.name}', category.id);
      }
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
    final plan = _plan;
    final failed = _results.values
        .where((result) => result.error != null)
        .length;
    final isWide = context.isWide;

    final templateCard = BookImportTemplateCard(onDownload: _download);
    final uploadCard = BookImportUploadCard(
      fileName: _fileName,
      problem: _problem,
      isImporting: _importing,
      onChoose: _choose,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Import books')),
      body: IcueCenteredBody(
        maxWidth: double.infinity,
        child: ListView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: templateCard),
                  const SizedBox(width: 16),
                  Expanded(child: uploadCard),
                ],
              )
            else ...[
              templateCard,
              uploadCard,
            ],
            if (plan != null &&
                (plan.books.isNotEmpty || plan.issues.isNotEmpty)) ...[
              const SizedBox(height: 16),
              IcueFormSectionCard(
                title: '3. Review and import',
                icon: Icons.fact_check_outlined,
                children: [
                  BookImportSummaryCards(
                    plan: plan,
                    resultsCount: _results.length,
                    failedCount: failed,
                    isFinished: _finished,
                    isImporting: _importing,
                  ),
                  const SizedBox(height: 16),
                  if (plan.issues.isNotEmpty)
                    BookImportIssuesCard(issues: plan.issues)
                  else
                    BookImportPreviewSection(
                      plan: plan,
                      results: _results,
                      isImporting: _importing,
                      isFinished: _finished,
                      failedCount: failed,
                      copiesAdded: _copiesAdded,
                      onImport: _import,
                      onReset: _reset,
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
