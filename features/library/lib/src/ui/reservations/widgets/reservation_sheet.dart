import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/person_picker.dart';

/// Sheet to reserve a book that is currently unavailable (FRS 11.12).
class ReservationSheet extends StatefulWidget {
  const ReservationSheet({super.key, this.book});

  final LibraryBook? book;

  static Future<void> show(BuildContext context, {LibraryBook? book}) =>
      showFormPage(context, () => ReservationSheet(book: book));

  @override
  State<ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<ReservationSheet> {
  final _bookSearch = TextEditingController();
  LibraryPerson? _person;
  LibraryBook? _selectedBook;
  String? _libraryId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.book;
  }

  @override
  void dispose() {
    _bookSearch.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final person = _person;
    if (person == null) {
      return showMessage(context, 'Choose the student or teacher');
    }
    final book = _selectedBook;
    if (book == null) return showMessage(context, 'Select a book to reserve');
    final libraryId = _libraryId;
    if (libraryId == null) return showMessage(context, 'Select a library');

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await libraryProvider.createReservation({
      'person': person.toPayload(),
      'catalogueId': book.id,
      'libraryId': libraryId,
    });
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
      showMessage(context, 'Reservation placed');
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Could not place reservation',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active &&
            libraryProvider.access.campusIds.contains(schoolLibrary.campusId))
          schoolLibrary,
    ];
    if (_libraryId == null && libraries.isNotEmpty) {
      _libraryId = libraries.first.id;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reserve a book', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        PersonPicker(onChanged: (person) => _person = person),
        const SizedBox(height: 12),
        if (widget.book != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(widget.book!.title),
            subtitle: Text(widget.book!.authorLine),
          )
        else
          Autocomplete<LibraryBook>(
            displayStringForOption: (book) => book.title,
            optionsBuilder: (val) async {
              final value = val.text.trim();
              if (value.isEmpty) return const [];
              final result = await libraryProvider.searchBooks(
                value,
                limit: 10,
              );
              return result.items;
            },
            onSelected: (book) => setState(() => _selectedBook = book),
            fieldViewBuilder: (context, controller, focus, onFieldSubmitted) =>
                TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'Search book by title, author or ISBN',
                  ),
                ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _libraryId,
          decoration: const InputDecoration(labelText: 'Preferred library'),
          items: [
            for (final schoolLibrary in libraries)
              DropdownMenuItem(
                value: schoolLibrary.id,
                child: Text(schoolLibrary.name),
              ),
          ],
          onChanged: (value) => setState(() => _libraryId = value),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Reserve'),
        ),
      ],
    );
  }
}
