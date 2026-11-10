import 'dart:async';

import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/mock_books.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_class_section.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_form_sections.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';
import 'package:school_library/src/ui/catalogue/widgets/new_copies_section.dart';

class BookFormPage extends StatefulWidget {
  const BookFormPage({super.key, this.book});

  final LibraryBook? book;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _form = GlobalKey<FormState>();
  final _copiesRequestId = newRequestId();
  final _copies = TextEditingController(text: '1');
  final _barcodes = <TextEditingController>[];
  bool _generateBarcodes = true;
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
  late final Set<int> _classIds = {...?_existingBook?.classIds};
  bool _busy = false;
  bool _dirty = false;
  bool _duplicate = false;
  Timer? _duplicateTimer;

  List<TextEditingController> get _identityFields => [
    _title,
    _authors,
    _edition,
    _publisher,
    _year,
  ];

  /// Looks up the book as its identifying details are typed, so a duplicate shows before Save.
  void _checkDuplicate() {
    _duplicateTimer?.cancel();
    _duplicateTimer = Timer(const Duration(milliseconds: 500), () async {
      final provider = context.read<LibraryProvider>();
      final existingId = await provider.findTitleId({
        'title': _title.text.trim(),
        'authors': splitList(_authors.text),
        'edition': blankToNull(_edition),
        'publisher': blankToNull(_publisher),
        'year': int.tryParse(_year.text.trim()),
      });
      final duplicate =
          existingId != null &&
          existingId != (_existingBook?.id ?? _copiesRequestId);
      if (mounted && duplicate != _duplicate) {
        setState(() => _duplicate = duplicate);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _identityFields) {
      controller.addListener(_checkDuplicate);
    }
    unawaited(context.read<LibraryProvider>().loadStandards());
  }

  @override
  void dispose() {
    _duplicateTimer?.cancel();
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

  int _mockIndex = 0;

  /// Fills the form with the next sample book (client-side only, nothing is saved).
  void _prefillMock() {
    final mock = mockBooks[_mockIndex++ % mockBooks.length];
    final provider = context.read<LibraryProvider>();
    final hint = mock.categoryHint.toLowerCase();
    final category = provider.categories.where(
      (category) =>
          category.active && category.name.toLowerCase().contains(hint),
    );
    setState(() {
      _title.text = mock.title;
      _subtitle.text = mock.subtitle ?? '';
      _authors.text = mock.authors;
      _publisher.text = mock.publisher;
      _edition.text = '1st';
      _year.text = '${mock.year}';
      _language.text = mock.language;
      _pages.text = '${mock.pages}';
      _shelf.text = 'A-${_mockIndex.toString().padLeft(2, '0')}';
      _keywords.text = [
        mock.categoryHint.toLowerCase(),
        ...mock.title.toLowerCase().split(' ').where((word) => word.length > 3),
      ].join(', ');
      _description.text = mock.description;
      _categoryId = category.firstOrNull?.id;
      _classIds
        ..clear()
        ..addAll([
          for (final standard in provider.standards)
            if (mock.classNumbers.any(
              (number) => RegExp('\\b$number\\b').hasMatch(standard.name),
            ))
              standard.id,
        ]);
      _dirty = true;
    });
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
            AppButton(
              label: 'Keep editing',
              onPressed: () => Navigator.of(context).pop(false),
              variant: AppButtonVariant.ghost,
            ),
            AppButton(
              label: 'Discard',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ) ??
      false;

  /// The copies to create with a new book; null when editing or when none are asked for.
  Map<String, Object?>? _newCopies() {
    final quantity = int.tryParse(_copies.text.trim()) ?? 0;
    if (_existingBook != null || quantity < 1) return null;
    return {
      'libraryId': _libraryId,
      'quantity': quantity,
      if (!_generateBarcodes)
        'barcodes': [
          for (final controller in _barcodes) controller.text.trim(),
        ],
      'shelf': blankToNull(_shelf),
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _duplicate) return;
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final title = _title.text.trim();
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => libraryProvider.saveBook(
        {
          // Stable per form, so a retry after the copies failed edits the title it already made.
          'id': _existingBook?.id ?? _copiesRequestId,
          'title': title,
          'subtitle': blankToNull(_subtitle),
          'authors': splitList(_authors.text),
          'publisher': blankToNull(_publisher),
          'edition': blankToNull(_edition),
          'year': int.tryParse(_year.text.trim()),
          'language': blankToNull(_language),
          'categoryId': _categoryId,
          'classIds': _classIds.toList(),
          'description': blankToNull(_description),
          'pages': int.tryParse(_pages.text.trim()),
          'shelf': blankToNull(_shelf),
          'keywords': splitList(_keywords.text),
        },
        copies: _newCopies(),
        copiesRequestId: _copiesRequestId,
      ),
    );
    final created = libraryProvider.createdBarcodes;
    if (saved && created.isNotEmpty) {
      final shelf = blankToNull(_shelf);
      unawaited(
        shareCopyLabels(title, [
          for (final barcode in created) (barcode: barcode, shelf: shelf),
        ]),
      );
    }
    if (saved && mounted) {
      _dirty = false;
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
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
      BookClassSection(
        standards: libraryProvider.standards,
        selectedIds: _classIds,
        onChanged: (classIds) => setState(() {
          _classIds
            ..clear()
            ..addAll(classIds);
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
          generate: _generateBarcodes,
          onGenerateChanged: (value) =>
              setState(() => _generateBarcodes = value),
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
            if (!editing)
              IconButton(
                tooltip: 'Fill sample data',
                icon: const Icon(Icons.auto_fix_high_rounded),
                onPressed: _busy ? null : _prefillMock,
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
        body: CenteredBody(
          child: Form(
            key: _form,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_duplicate)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'This book already exists in the catalogue (same title, '
                      'first author, edition, publisher and year).',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
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
                  child: AppButton(
                    label: _busy
                        ? 'Saving…'
                        : (editing ? 'Update book' : 'Save book'),
                    onPressed: _busy ? null : _save,
                    leadingIcon: Icons.check_circle_outline,
                    isLoading: _busy,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
