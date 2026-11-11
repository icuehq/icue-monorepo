import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';
import 'package:school_library/src/ui/catalogue/widgets/new_copies_section.dart';

/// Adds copies to an existing title and opens their labels for printing.
class AddCopiesForm extends StatefulWidget {
  const AddCopiesForm({super.key, required this.book});

  final LibraryBook book;

  static Future<void> show(BuildContext context, LibraryBook book) =>
      showFormPage(context, () => AddCopiesForm(book: book));

  @override
  State<AddCopiesForm> createState() => _AddCopiesFormState();
}

class _AddCopiesFormState extends State<AddCopiesForm> {
  final _form = GlobalKey<FormState>();

  /// Stable per form, so a retry never creates the copies twice.
  final _requestId = newRequestId();
  final _copies = TextEditingController(text: '1');
  final _barcodes = <TextEditingController>[];
  late final _shelf = TextEditingController(text: widget.book.shelf);
  bool _generateBarcodes = true;
  String? _libraryId;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_copies, _shelf, ..._barcodes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final shelf = blankToNull(_shelf);
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => libraryProvider.addCopies(widget.book.id, {
        'libraryId': _libraryId,
        'quantity': int.parse(_copies.text.trim()),
        if (!_generateBarcodes)
          'barcodes': [
            for (final controller in _barcodes) controller.text.trim(),
          ],
        'shelf': shelf,
      }, requestId: _requestId),
    );
    if (saved) {
      unawaited(
        shareCopyLabels(widget.book.title, [
          for (final barcode in libraryProvider.createdBarcodes)
            (barcode: barcode, shelf: shelf),
        ]),
      );
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active) schoolLibrary,
    ];
    _libraryId ??= libraries.firstOrNull?.id;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add copies of ${widget.book.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          NewCopiesSection(
            copies: _copies,
            barcodes: _barcodes,
            libraries: libraries,
            libraryId: _libraryId,
            onLibraryChanged: (value) => setState(() => _libraryId = value),
            generate: _generateBarcodes,
            onGenerateChanged: (value) =>
                setState(() => _generateBarcodes = value),
            allowNone: false,
          ),
          const SizedBox(height: 14),
          IcueTextField(
            controller: _shelf,
            label: 'Shelf',
            icon: Icons.shelves,
          ),
          const SizedBox(height: 20),
          IcueButton(
            label: _busy ? 'Saving…' : 'Add copies',
            onPressed: _busy ? null : _save,
            leadingIcon: Icons.add_rounded,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}
