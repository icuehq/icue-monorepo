import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/mock_books.dart';

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
  late final LibraryBook? _existingBook = widget.book;
  late final _title = TextEditingController(text: _existingBook?.title);
  late final _subtitle = TextEditingController(text: _existingBook?.subtitle);
  late final _authors = TextEditingController(
    text: _existingBook?.authors.join(', '),
  );
  late final _isbn10 = TextEditingController(text: _existingBook?.isbn10);
  late final _isbn13 = TextEditingController(text: _existingBook?.isbn13);
  late final _publisher = TextEditingController(text: _existingBook?.publisher);
  late final _edition = TextEditingController(text: _existingBook?.edition);
  late final _year = TextEditingController(
    text: _existingBook?.year?.toString(),
  );
  late final _language = TextEditingController(text: _existingBook?.language);
  late final _pages = TextEditingController(
    text: _existingBook?.pages?.toString(),
  );
  late final _classNo = TextEditingController(
    text: _existingBook?.classificationNumber,
  );
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
      _isbn10,
      _isbn13,
      _publisher,
      _edition,
      _year,
      _language,
      _pages,
      _classNo,
      _keywords,
      _description,
    ]) {
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
      _isbn13.text = sample.isbn13;
      _isbn10.text = sample.isbn10;
      _publisher.text = sample.publisher;
      _edition.text = sample.edition;
      _year.text = '${sample.year}';
      _language.text = sample.language;
      _pages.text = '${sample.pages}';
      _classNo.text = sample.classificationNumber;
      _keywords.text = sample.keywords.join(', ');
      _description.text = sample.description;
      _categoryId = category?.id ?? categories.firstOrNull?.id;
      _dirty = true;
    });
  }

  String? _validateYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1000 || year > 2200) {
      return 'Year 1000–2200';
    }
    return null;
  }

  String? _validatePages(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final pages = int.tryParse(text);
    if (pages == null || pages < 1 || pages > 100000) {
      return 'Enter a valid page count';
    }
    return null;
  }

  String? _validateAuthors(String? value) {
    final authors = splitList(value ?? '');
    if (authors.isEmpty) return 'At least one author is required';
    if (authors.length > 10) return 'At most 10 authors allowed';
    return null;
  }

  String? _validateKeywords(String? value) {
    final keywords = splitList(value ?? '');
    if (keywords.length > 20) return 'At most 20 keywords allowed';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().saveBook({
        'id': ?_existingBook?.id,
        'title': _title.text.trim(),
        'subtitle': blankToNull(_subtitle),
        'authors': splitList(_authors.text),
        'isbn10': blankToNull(_isbn10),
        'isbn13': blankToNull(_isbn13),
        'publisher': blankToNull(_publisher),
        'edition': blankToNull(_edition),
        'year': int.tryParse(_year.text.trim()),
        'language': blankToNull(_language),
        'categoryId': _categoryId,
        'description': blankToNull(_description),
        'pages': int.tryParse(_pages.text.trim()),
        'classificationNumber': blankToNull(_classNo),
        'keywords': splitList(_keywords.text),
      }, requestId: _requestId),
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
    // Inactive categories stay selectable only when the book already uses one.
    final categories = libraryProvider.categories
        .where(
          (category) =>
              category.active || category.id == _existingBook?.categoryId,
        )
        .toList();

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
        body: CenteredBody(
          maxWidth: Breakpoints.formMaxWidth,
          child: Form(
            key: _form,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                FormSectionCard(
                  title: 'Basic information',
                  icon: Icons.auto_stories_outlined,
                  children: [
                    AppTextField(
                      controller: _title,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: requiredText,
                      label: 'Title *',
                      hintText: 'e.g. To Kill a Mockingbird',
                      icon: Icons.title_rounded,
                    ),
                    AppTextField(
                      controller: _subtitle,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      label: 'Subtitle',
                      hintText: 'e.g. A Novel',
                      icon: Icons.subtitles_outlined,
                    ),
                    AppTextField(
                      controller: _authors,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _validateAuthors,
                      label: 'Authors *',
                      hintText: 'e.g. Harper Lee, J.K. Rowling',
                      icon: Icons.people_outline_rounded,
                      helperText: 'Comma-separated list of authors',
                    ),
                    AppDropdown<String>(
                      value: _categoryId,
                      items: [
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.parentId == null
                                  ? category.name
                                  : '${libraryProvider.category(category.parentId)?.name ?? ''} › ${category.name}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _categoryId = value);
                        if (!_dirty) setState(() => _dirty = true);
                      },
                      validator: (value) => value == null ? 'Required' : null,
                      label: 'Category *',
                      icon: Icons.category_outlined,
                    ),
                  ],
                ),
                FormSectionCard(
                  title: 'Identification & shelf location',
                  icon: Icons.qr_code_2_outlined,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _isbn13,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\-]'),
                              ),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            label: 'ISBN-13',
                            hintText: '978-3-16-148410-0',
                            icon: Icons.qr_code_2_outlined,
                            helperText: '13-digit standard identifier',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _isbn10,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9Xx\-]'),
                              ),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            label: 'ISBN-10',
                            hintText: '0-306-40615-2',
                            icon: Icons.pin_outlined,
                            helperText: '10-digit legacy identifier',
                          ),
                        ),
                      ],
                    ),
                    AppTextField(
                      controller: _classNo,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      label: 'Classification / Call number',
                      hintText: 'e.g. DDC 823.91 or QA76.73',
                      icon: Icons.tag_rounded,
                      helperText: 'Shelf location or classification code',
                    ),
                  ],
                ),
                FormSectionCard(
                  title: 'Publication details',
                  icon: Icons.menu_book_outlined,
                  children: [
                    AppTextField(
                      controller: _publisher,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      label: 'Publisher',
                      hintText: 'e.g. Penguin Random House',
                      icon: Icons.business_outlined,
                    ),
                    AppTextField(
                      controller: _edition,
                      maxLength: 50,
                      textInputAction: TextInputAction.next,
                      label: 'Edition',
                      hintText: 'e.g. 2nd Edition or Revised',
                      icon: Icons.bookmark_border_rounded,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _year,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: _validateYear,
                            label: 'Publication year',
                            hintText: 'YYYY',
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _pages,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: _validatePages,
                            label: 'Pages',
                            hintText: 'e.g. 320',
                            icon: Icons.format_list_numbered_rounded,
                          ),
                        ),
                      ],
                    ),
                    AppTextField(
                      controller: _language,
                      maxLength: 50,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      label: 'Language',
                      hintText: 'e.g. English, Hindi',
                      icon: Icons.translate_rounded,
                    ),
                  ],
                ),
                FormSectionCard(
                  title: 'Description & tags',
                  icon: Icons.notes_rounded,
                  children: [
                    AppTextField(
                      controller: _keywords,
                      textInputAction: TextInputAction.next,
                      validator: _validateKeywords,
                      label: 'Keywords / Search tags',
                      hintText: 'e.g. Classic, Fiction, Historical',
                      icon: Icons.sell_outlined,
                      helperText:
                          'Comma-separated keywords for catalogue search',
                    ),
                    AppTextField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      label: 'Description',
                      hintText: 'Brief summary or notes about the book',
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ),
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
                      _busy
                          ? 'Saving…'
                          : (editing ? 'Update book' : 'Save book'),
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
      ),
    );
  }
}
