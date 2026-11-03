import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    showMessage(context, stockProvider.errorMessage ?? 'Could not save');
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
    this.campusId,
    this.prefixIcon,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? exclude;
  final Widget? prefixIcon;

  /// Only stores of this campus.
  final int? campusId;

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<InventoryProvider>().stores.where(
      (store) =>
          store.active &&
          store.id != exclude &&
          (campusId == null || store.campusId == campusId),
    );
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: prefixIcon),
      items: [
        for (final store in stores)
          DropdownMenuItem(
            value: store.id,
            child: Text(store.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
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
