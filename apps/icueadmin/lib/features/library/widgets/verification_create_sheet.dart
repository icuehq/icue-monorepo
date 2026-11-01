import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Starts a verification of one library, optionally limited to a shelf.
class VerificationCreateSheet extends StatefulWidget {
  const VerificationCreateSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showInvSheet(context, () => const VerificationCreateSheet());

  @override
  State<VerificationCreateSheet> createState() =>
      _VerificationCreateSheetState();
}

class _VerificationCreateSheetState extends State<VerificationCreateSheet> {
  final _shelf = TextEditingController();
  String? _library;
  bool _busy = false;

  @override
  void dispose() {
    _shelf.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_library == null) {
      invSnack(context, 'Pick a library');
      return;
    }
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    await libSubmit(
      context,
      () => p.createVerification({
        'libraryId': _library,
        'shelf': ?blankToNull(_shelf),
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
        Text(
          'New stock verification',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _library,
          decoration: const InputDecoration(labelText: 'Library'),
          items: [
            for (final l in libs)
              DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          onChanged: (v) => setState(() => _library = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _shelf,
          decoration: const InputDecoration(
            labelText: 'Shelf (optional, exact match)',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Start counting'),
        ),
      ],
    );
  }
}
