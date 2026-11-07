import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_form_sections.dart';
import 'package:school_library/src/ui/catalogue/widgets/mock_books.dart';
import 'package:school_library/src/ui/catalogue/widgets/new_copies_section.dart';

class BookFormPage extends StatefulWidget {
  const BookFormPage({super.key, this.book});

  final LibraryBook? book;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  /// Which [mockBooks] entry the next "Fill sample" press uses.
  static int _nextSample = 0;

  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _copiesRequestId = newRequestId();
  final _copies = TextEditingController(text: '1');
  final _barcodes = <TextEditingController>[];
  String? _libraryId;
  late final LibraryBook? _existingBook = widget.book;
  late final _title = TextEditingController(text: _existingBook?.title);
  late final _subtitle = TextEditingController(text: _existingBook?.subtitle);
  late final _authors = TextEditingController(
    text: _existingBook?.authors.join(', '),
  );
  late final _publisher = TextEditingController(text: _existingBook?.publisher);
  late final _edition = TextEditingController(text: _existingBook?.edition);
  late final _year = TextEditingController(
    text: _existingBook?.year?.toString(),
  );
  late final _language = TextEditingController(text: _existingBook?.language);
  late final _pages = TextEditingController(
    text: _existingBook?.pages?.toString(),
  );
  late final _shelf = TextEditingController(text: _existingBook?.shelf);
  late final _keywords = TextEditingController(
    text: _existingBook?.keywords.join(', '),
  );
  late final _description = TextEditingController(
    text: _existingBook?.description,
  );
  late String? _categoryId = _existingBook?.categoryId;
  bool _busy = false;
  bool _dirty = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _subtitle,
      _authors,
      _publisher,
      _edition,
      _year,
      _language,
      _pages,
      _shelf,
      _copies,
      _keywords,
      _description,
    ]) {
      controller.dispose();
    }
    for (final controller in _barcodes) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'Your unsaved changes to this book will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  /// Fills the form with the next entry of [mockBooks] (debug builds, new books only).
  void _fillSample() {
    final sample = mockBooks[_nextSample++ % mockBooks.length];
    final categories = context.read<LibraryProvider>().categories.where(
      (category) => category.active,
    );
    final category = categories
        .where(
          (category) =>
              category.name.toLowerCase() == sample.categoryName.toLowerCase(),
        )
        .firstOrNull;
    setState(() {
      _title.text = sample.title;
      _subtitle.text = sample.subtitle ?? '';
      _authors.text = sample.authors.join(', ');
      _publisher.text = sample.publisher;
      _edition.text = sample.edition;
      _year.text = '${sample.year}';
      _language.text = sample.language;
      _pages.text = '${sample.pages}';
      _shelf.text = 'Shelf A-3, Rack 2';
      _keywords.text = sample.keywords.join(', ');
      _description.text = sample.description;
      _categoryId = category?.id ?? categories.firstOrNull?.id;
      _dirty = true;
    });
  }

  /// The copies to create with a new book; null when editing or when none are asked for.
  Map<String, Object?>? _newCopies() {
    final quantity = int.tryParse(_copies.text.trim()) ?? 0;
    if (_existingBook != null || quantity < 1) return null;
    return {
      'libraryId': _libraryId,
      'quantity': quantity,
      'barcodes': [for (final controller in _barcodes) controller.text.trim()],
      'shelf': blankToNull(_shelf),
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().saveBook(
        {
          'id': ?_existingBook?.id,
          'title': _title.text.trim(),
          'subtitle': blankToNull(_subtitle),
          'authors': splitList(_authors.text),
          'publisher': blankToNull(_publisher),
          'edition': blankToNull(_edition),
          'year': int.tryParse(_year.text.trim()),
          'language': blankToNull(_language),
          'categoryId': _categoryId,
          'description': blankToNull(_description),
          'pages': int.tryParse(_pages.text.trim()),
          'shelf': blankToNull(_shelf),
          'keywords': splitList(_keywords.text),
        },
        requestId: _requestId,
        copies: _newCopies(),
        copiesRequestId: _copiesRequestId,
      ),
    );
    if (saved && mounted) {
      _dirty = false;
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final editing = _existingBook != null;
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active &&
            libraryProvider.access.campusIds.contains(schoolLibrary.campusId))
          schoolLibrary,
    ];
    _libraryId ??= libraries.firstOrNull?.id;
    // Inactive categories stay selectable only when the book already uses one.
    final categories = libraryProvider.categories
        .where(
          (category) =>
              category.active || category.id == _existingBook?.categoryId,
        )
        .toList();

    final leftSections = <Widget>[
      BookBasicSection(
        title: _title,
        subtitle: _subtitle,
        authors: _authors,
        categoryId: _categoryId,
        categories: categories,
        categoryLabel: (category) => category.parentId == null
            ? category.name
            : '${libraryProvider.category(category.parentId)?.name ?? ''} › ${category.name}',
        onCategoryChanged: (value) => setState(() {
          _categoryId = value;
          _dirty = true;
        }),
      ),
      BookPublicationSection(
        publisher: _publisher,
        edition: _edition,
        year: _year,
        pages: _pages,
        language: _language,
      ),
    ];
    final rightSections = <Widget>[
      BookIdentificationSection(shelf: _shelf),
      if (!editing)
        NewCopiesSection(
          copies: _copies,
          barcodes: _barcodes,
          libraries: libraries,
          libraryId: _libraryId,
          onLibraryChanged: (value) => setState(() => _libraryId = value),
        ),
      BookDescriptionSection(keywords: _keywords, description: _description),
    ];

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Edit book' : 'Add book'),
          actions: [
            if (kDebugMode && !editing)
              TextButton.icon(
                onPressed: _busy ? null : _fillSample,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Fill sample'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            IconButton(
              tooltip: editing ? 'Update book' : 'Save book',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
        body: Form(
          key: _form,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (context.isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: leftSections)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: rightSections)),
                  ],
                )
              else ...[
                ...leftSections,
                ...rightSections,
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _busy ? 'Saving…' : (editing ? 'Update book' : 'Save book'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
