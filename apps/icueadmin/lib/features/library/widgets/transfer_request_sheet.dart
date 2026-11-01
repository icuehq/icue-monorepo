import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Request a transfer of available copies from one library to another.
class TransferRequestSheet extends StatefulWidget {
  const TransferRequestSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showFormSheet(context, () => const TransferRequestSheet());

  @override
  State<TransferRequestSheet> createState() => _TransferRequestSheetState();
}

class _TransferRequestSheetState extends State<TransferRequestSheet> {
  final _remarks = TextEditingController();
  final List<String> _copyIds = [];
  String? _from;
  String? _to;
  bool _busy = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _add(String code) async {
    final copy = await context.read<LibraryProvider>().findCopy(code);
    if (!mounted) return;
    if (copy == null) {
      showMessage(context, 'No copy found for "$code"');
    } else if (_from != null && copy.libraryId != _from) {
      showMessage(
        context,
        '${copy.accessionNumber} is not in the source library',
      );
    } else if (copy.status != 'available') {
      showMessage(context, '${copy.accessionNumber} is ${copy.status}');
    } else if (!_copyIds.contains(copy.id)) {
      setState(() {
        _from ??= copy.libraryId;
        _copyIds.add(copy.id);
      });
    }
  }

  Future<void> _submit() async {
    if (_from == null || _to == null || _copyIds.isEmpty) {
      showMessage(context, 'Pick the destination and scan at least one copy');
      return;
    }
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    await submitAndClose<LibraryProvider>(
      context,
      () => libraryProvider.requestTransfer({
        'fromLibraryId': _from,
        'toLibraryId': _to,
        'copyIds': _copyIds,
        'remarks': ?blankToNull(_remarks),
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final libraries = context
        .watch<LibraryProvider>()
        .libraries
        .where((schoolLibrary) => schoolLibrary.active)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('New transfer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ScanField(
          hint: 'Scan or enter accession no. (source library is taken from the first)',
          clearOnScan: true,
          onScan: _add,
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final copyId in _copyIds)
              InputChip(
                label: Text(copyId),
                onDeleted: () => setState(() {
                  _copyIds.remove(copyId);
                  if (_copyIds.isEmpty) _from = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _to,
          decoration: const InputDecoration(labelText: 'Destination library'),
          items: [
            for (final schoolLibrary in libraries)
              if (schoolLibrary.id != _from)
                DropdownMenuItem(
                  value: schoolLibrary.id,
                  child: Text(schoolLibrary.name),
                ),
          ],
          onChanged: (value) => setState(() => _to = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _remarks,
          decoration: const InputDecoration(labelText: 'Remarks'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Request transfer'),
        ),
      ],
    );
  }
}
