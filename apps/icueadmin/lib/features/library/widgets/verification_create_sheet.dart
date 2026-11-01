import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Starts a verification of one library, optionally limited to a shelf.
class VerificationCreateSheet extends StatefulWidget {
  const VerificationCreateSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showFormSheet(context, () => const VerificationCreateSheet());

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
      showMessage(context, 'Pick a library');
      return;
    }
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    await submitAndClose<LibraryProvider>(
      context,
      () => libraryProvider.createVerification({
        'libraryId': _library,
        'shelf': ?blankToNull(_shelf),
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
        Text(
          'New stock verification',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _library,
          decoration: const InputDecoration(labelText: 'Library'),
          items: [
            for (final schoolLibrary in libraries)
              DropdownMenuItem(
                value: schoolLibrary.id,
                child: Text(schoolLibrary.name),
              ),
          ],
          onChanged: (value) => setState(() => _library = value),
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
