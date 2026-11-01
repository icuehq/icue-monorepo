import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Request a transfer of available copies from one library to another.
class TransferRequestSheet extends StatefulWidget {
  const TransferRequestSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showInvSheet(context, () => const TransferRequestSheet());

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
    final c = await context.read<LibraryProvider>().findCopy(code);
    if (!mounted) return;
    if (c == null) {
      invSnack(context, 'No copy found for "$code"');
    } else if (_from != null && c.libraryId != _from) {
      invSnack(context, '${c.accessionNo} is not in the source library');
    } else if (c.status != 'available') {
      invSnack(context, '${c.accessionNo} is ${c.status}');
    } else if (!_copyIds.contains(c.id)) {
      setState(() {
        _from ??= c.libraryId;
        _copyIds.add(c.id);
      });
    }
  }

  Future<void> _submit() async {
    if (_from == null || _to == null || _copyIds.isEmpty) {
      invSnack(context, 'Pick the destination and scan at least one copy');
      return;
    }
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    await libSubmit(
      context,
      () => p.requestTransfer({
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
    final libs = context
        .watch<LibraryProvider>()
        .libraries
        .where((l) => l.active)
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
            for (final c in _copyIds)
              InputChip(
                label: Text(c),
                onDeleted: () => setState(() {
                  _copyIds.remove(c);
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
            for (final l in libs)
              if (l.id != _from)
                DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          onChanged: (v) => setState(() => _to = v),
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
