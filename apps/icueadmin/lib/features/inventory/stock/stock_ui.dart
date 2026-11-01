import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows its document number and (when [close]) leaves the screen.
Future<bool> stockSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(StockProvider p) call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final p = context.read<StockProvider>();
  final nav = Navigator.of(context);
  final res = await call(p);
  if (!context.mounted) return res != null;
  if (res == null) {
    invSnack(context, p.errorMessage ?? 'Could not save');
    return false;
  }
  final number = res['number'];
  invSnack(context, number == null ? done : '$done · $number');
  if (close) nav.pop();
  return true;
}

class StoreDropdown extends StatelessWidget {
  const StoreDropdown({
    required this.value,
    required this.onChanged,
    this.label = 'Store',
    this.exclude,
    this.campusId,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? exclude;

  /// Only stores of this campus.
  final int? campusId;

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<InventoryProvider>().stores.where(
      (s) =>
          s.active &&
          s.id != exclude &&
          (campusId == null || s.campusId == campusId),
    );
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final s in stores)
          DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.code})')),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}

/// Makes sure masters (access, stores) are loaded before a stock screen uses them.
void ensureMasters(BuildContext context) {
  final p = context.read<InventoryProvider>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (p.stores.isEmpty && !p.isLoading) p.loadMasters();
  });
}

String statusLabel(String s) =>
    s.replaceAll('_', ' ').replaceRange(0, 1, s.substring(0, 1).toUpperCase());
