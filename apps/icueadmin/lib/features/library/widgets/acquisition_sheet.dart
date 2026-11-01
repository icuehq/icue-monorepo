import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Records an acquisition of [book] and creates its copies (FRS 11.5–11.6).
/// Pops with the new accession numbers.
class AcquisitionSheet extends StatefulWidget {
  const AcquisitionSheet({super.key, required this.book});

  final LibraryBook book;

  static Future<List<String>?> show(BuildContext context, LibraryBook book) =>
      showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(child: AcquisitionSheet(book: book)),
        ),
      );

  @override
  State<AcquisitionSheet> createState() => _AcquisitionSheetState();
}

class _AcquisitionSheetState extends State<AcquisitionSheet> {
  static const _types = {
    'purchase': 'Purchase',
    'donation': 'Donation',
    'opening': 'Opening stock',
  };

  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _vendor = TextEditingController();
  final _ref = TextEditingController();
  final _shelf = TextEditingController();
  String _type = 'purchase';
  String _condition = 'good';
  String? _libraryId;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_quantity, _price, _vendor, _ref, _shelf]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ids = await libraryProvider.createAcquisition({
      'type': _type,
      'catalogueId': widget.book.id,
      'libraryId': _libraryId,
      'quantity': int.parse(_quantity.text.trim()),
      'price': double.tryParse(_price.text.trim()) ?? 0,
      'vendorOrDonor': blankToNull(_vendor),
      'reference': blankToNull(_ref),
      'shelf': blankToNull(_shelf),
      'condition': _condition,
    }, requestId: _requestId);
    if (!mounted) return;
    if (ids == null) {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Could not save');
    } else {
      navigator.pop(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active &&
            libraryProvider.access.campusIds.contains(schoolLibrary.campusId))
          schoolLibrary,
    ];
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add copies of ${widget.book.title}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Source *'),
            items: [
              for (final mapEntry in _types.entries)
                DropdownMenuItem(
                  value: mapEntry.key,
                  child: Text(mapEntry.value),
                ),
            ],
            onChanged: (value) => setState(() => _type = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _libraryId,
            decoration: const InputDecoration(labelText: 'Library *'),
            items: [
              for (final schoolLibrary in libraries)
                DropdownMenuItem(
                  value: schoolLibrary.id,
                  child: Text(schoolLibrary.name),
                ),
            ],
            onChanged: (value) => _libraryId = value,
            validator: (value) => value == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of copies *'),
            validator: (value) {
              final number = int.tryParse(value?.trim() ?? '');
              return number == null || number < 1 || number > 100
                  ? '1 to 100'
                  : null;
            },
          ),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == 'purchase'
                  ? 'Price per copy *'
                  : 'Price per copy',
            ),
            validator: (value) {
              final number = double.tryParse(value?.trim() ?? '');
              if (_type == 'purchase') {
                return number == null || number <= 0 ? 'Enter the price' : null;
              }
              return (value ?? '').trim().isNotEmpty &&
                      (number == null || number < 0)
                  ? 'Invalid'
                  : null;
            },
          ),
          TextFormField(
            controller: _vendor,
            decoration: InputDecoration(
              labelText: _type == 'donation' ? 'Donor' : 'Vendor',
            ),
          ),
          TextFormField(
            controller: _ref,
            decoration: const InputDecoration(labelText: 'Invoice / reference'),
          ),
          TextFormField(
            controller: _shelf,
            decoration: const InputDecoration(labelText: 'Shelf / location'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _condition,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: [
              for (final copyCondition in copyConditions)
                DropdownMenuItem(
                  value: copyCondition,
                  child: Text(copyCondition),
                ),
            ],
            onChanged: (value) => _condition = value!,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Add copies'),
          ),
        ],
      ),
    );
  }
}
