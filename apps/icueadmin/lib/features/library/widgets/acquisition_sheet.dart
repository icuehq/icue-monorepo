import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Records an acquisition of [book] and creates its copies (FRS 11.5–11.6).
/// Pops with the new accession numbers.
class AcquisitionSheet extends StatefulWidget {
  const AcquisitionSheet({super.key, required this.book});

  final LibBook book;

  static Future<List<String>?> show(BuildContext context, LibBook book) =>
      showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
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
  final _qty = TextEditingController(text: '1');
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
    for (final c in [_qty, _price, _vendor, _ref, _shelf]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final ids = await p.createAcquisition({
      'type': _type,
      'catalogueId': widget.book.id,
      'libraryId': _libraryId,
      'qty': int.parse(_qty.text.trim()),
      'price': double.tryParse(_price.text.trim()) ?? 0,
      'vendorOrDonor': blankToNull(_vendor),
      'reference': blankToNull(_ref),
      'shelf': blankToNull(_shelf),
      'condition': _condition,
    }, requestId: _requestId);
    if (!mounted) return;
    if (ids == null) {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Could not save');
    } else {
      nav.pop(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<LibraryProvider>();
    final libs = [
      for (final l in p.libraries)
        if (l.active && p.access.campuses.contains(l.campusId)) l,
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
              for (final e in _types.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _libraryId,
            decoration: const InputDecoration(labelText: 'Library *'),
            items: [
              for (final l in libs)
                DropdownMenuItem(value: l.id, child: Text(l.name)),
            ],
            onChanged: (v) => _libraryId = v,
            validator: (v) => v == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of copies *'),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              return n == null || n < 1 || n > 100 ? '1 to 100' : null;
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
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              if (_type == 'purchase') {
                return n == null || n <= 0 ? 'Enter the price' : null;
              }
              return (v ?? '').trim().isNotEmpty && (n == null || n < 0)
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
              for (final c in copyConditions)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => _condition = v!,
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
