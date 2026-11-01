import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Runs [save]; closes the sheet/page on success, else shows the provider error.
Future<void> libSubmit(
  BuildContext context,
  Future<bool> Function() save,
) async {
  final provider = context.read<LibraryProvider>();
  final nav = Navigator.of(context);
  final ok = await save();
  if (!context.mounted) return;
  if (ok) {
    nav.pop();
  } else {
    invSnack(context, provider.errorMessage ?? 'Could not save');
  }
}

String? blankToNull(TextEditingController c) =>
    c.text.trim().isEmpty ? null : c.text.trim();

/// Comma-separated list → trimmed non-empty parts.
List<String> splitList(String v) => [
  for (final p in v.split(','))
    if (p.trim().isNotEmpty) p.trim(),
];

/// Empty-state action that creates the FRS default book categories.
class SeedCategoriesButton extends StatelessWidget {
  const SeedCategoriesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LibraryProvider>();
    if (!provider.access.can('lib.catalogue.manage')) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      icon: const Icon(Icons.auto_fix_high_rounded),
      label: const Text('Add default categories'),
      onPressed: () async {
        final ok = await provider.seedDefaults();
        if (context.mounted && !ok) {
          invSnack(context, provider.errorMessage ?? 'Failed');
        }
      },
    );
  }
}
