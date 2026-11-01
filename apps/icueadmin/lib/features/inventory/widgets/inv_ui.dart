import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

void invSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [save]; closes the sheet/page on success, else shows the provider error.
Future<void> invSubmit(
  BuildContext context,
  Future<bool> Function() save,
) async {
  final provider = context.read<InventoryProvider>();
  final nav = Navigator.of(context);
  final ok = await save();
  if (!context.mounted) return;
  if (ok) {
    nav.pop();
  } else {
    invSnack(context, provider.errorMessage ?? 'Could not save');
  }
}

Future<void> showInvSheet(BuildContext context, Widget Function() form) =>
    showModalBottomSheet<void>(
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
        child: SingleChildScrollView(child: form()),
      ),
    );

String? requiredText(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

String? optionalNumber(String? v) =>
    (v == null || v.trim().isEmpty || double.tryParse(v.trim()) != null)
    ? null
    : 'Enter a number';

class InactiveBadge extends StatelessWidget {
  const InactiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Chip(
    label: const Text('Inactive'),
    visualDensity: VisualDensity.compact,
    backgroundColor: Colors.grey.shade200,
    labelStyle: const TextStyle(fontSize: 11),
  );
}

/// Empty-state action that creates the FRS default categories and units.
class SeedDefaultsButton extends StatelessWidget {
  const SeedDefaultsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<InventoryProvider>();
    if (!provider.access.can('inv.settings')) return const SizedBox.shrink();
    return FilledButton.icon(
      icon: const Icon(Icons.auto_fix_high_rounded),
      label: const Text('Add default categories & units'),
      onPressed: () async {
        final ok = await provider.seedDefaults();
        if (context.mounted && !ok) {
          invSnack(context, provider.errorMessage ?? 'Failed');
        }
      },
    );
  }
}
