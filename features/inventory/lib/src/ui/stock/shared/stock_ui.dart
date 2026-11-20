import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows its document number and (when [close]) leaves the screen.
Future<bool> stockSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(StockProvider stockProvider) call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final stockProvider = context.read<StockProvider>();
  final navigator = Navigator.of(context);
  final result = await call(stockProvider);
  if (!context.mounted) return result != null;
  if (result == null) {
    IcueToast.error(context, stockProvider.errorMessage ?? 'Could not save');
    return false;
  }
  final number = result['number'];
  showMessage(context, number == null ? done : '$done · $number');
  if (close) navigator.pop();
  return true;
}

class StoreDropdown extends StatelessWidget {
  const StoreDropdown({
    required this.value,
    required this.onChanged,
    this.label = 'Store',
    this.exclude,
    this.prefixIcon,
    this.enabled = true,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? exclude;
  final Widget? prefixIcon;

  /// `false` when the store can no longer change (an existing record).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final stores = inventoryProvider.stores
        .where(
          (store) => (store.active || store.id == value) && store.id != exclude,
        )
        .toList();
    // A store manager with a single store has nothing to choose: assign it and show no dropdown.
    if (inventoryProvider.restricted && stores.length == 1) {
      final only = stores.single.id;
      if (enabled && value != only) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(only));
      }
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<String>(
      initialValue: stores.any((store) => store.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: prefixIcon),
      items: [
        for (final store in stores)
          DropdownMenuItem(
            value: store.id,
            child: Text(store.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? 'Required' : null,
    );
  }
}

/// Makes sure masters (access, stores) are loaded before a stock screen uses them.
void ensureMasters(BuildContext context) {
  final inventoryProvider = context.read<InventoryProvider>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (inventoryProvider.stores.isEmpty && !inventoryProvider.isLoading) {
      inventoryProvider.loadMasters();
    }
  });
}
