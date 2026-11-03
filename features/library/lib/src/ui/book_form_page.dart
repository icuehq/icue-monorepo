import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class BookFormPage extends StatefulWidget {
  const BookFormPage({super.key, this.book});

  final LibraryBook? book;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
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

  String? _optionalInt(String? value) =>
      (value == null ||
          value.trim().isEmpty ||
          int.tryParse(value.trim()) != null)
      ? null
      : 'Enter a whole number';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await submitAndClose<LibraryProvider>(
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
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    // Inactive categories stay selectable only when the book already uses one.
    final categories = libraryProvider.categories
        .where(
          (category) =>
              category.active || category.id == _existingBook?.categoryId,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingBook == null ? 'New book' : 'Edit book'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _subtitle,
              decoration: const InputDecoration(labelText: 'Subtitle'),
            ),
            TextFormField(
              controller: _authors,
              decoration: const InputDecoration(
                labelText: 'Authors * (comma-separated)',
              ),
              validator: (value) =>
                  splitList(value ?? '').isEmpty ? 'At least one author' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category *'),
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
              onChanged: (value) => _categoryId = value,
              validator: (value) => value == null ? 'Required' : null,
            ),
            TextFormField(
              controller: _isbn13,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ISBN-13'),
            ),
            TextFormField(
              controller: _isbn10,
              decoration: const InputDecoration(labelText: 'ISBN-10'),
            ),
            TextFormField(
              controller: _publisher,
              decoration: const InputDecoration(labelText: 'Publisher'),
            ),
            TextFormField(
              controller: _edition,
              decoration: const InputDecoration(labelText: 'Edition'),
            ),
            TextFormField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Publication year'),
              validator: _optionalInt,
            ),
            TextFormField(
              controller: _language,
              decoration: const InputDecoration(labelText: 'Language'),
            ),
            TextFormField(
              controller: _pages,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of pages'),
              validator: _optionalInt,
            ),
            TextFormField(
              controller: _classNo,
              decoration: const InputDecoration(
                labelText: 'Classification number',
              ),
            ),
            TextFormField(
              controller: _keywords,
              decoration: const InputDecoration(
                labelText: 'Keywords (comma-separated)',
              ),
            ),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
