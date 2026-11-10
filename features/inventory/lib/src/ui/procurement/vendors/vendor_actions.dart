import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Activates or deactivates [vendor]; deactivating asks first because it removes the vendor from new orders.
Future<void> toggleVendorActive(
  BuildContext context,
  InventoryVendor vendor,
) async {
  final procurementProvider = context.read<ProcurementProvider>();
  if (vendor.active) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate vendor'),
        content: Text(
          '${vendor.name} will no longer be offered on new quotations and '
          'purchase orders. Existing documents are not affected.',
        ),
        actions: [
          IcueButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
            variant: IcueButtonVariant.ghost,
          ),
          IcueButton(
            label: 'Deactivate',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  final result = await procurementProvider.setVendorActive(
    vendor.id,
    active: !vendor.active,
  );
  if (!context.mounted) return;
  if (result == null) {
    return showMessage(
      context,
      procurementProvider.errorMessage ?? 'Could not update the vendor',
    );
  }
  await procurementProvider.loadVendors();
  if (context.mounted) {
    showMessage(
      context,
      vendor.active ? 'Vendor deactivated' : 'Vendor activated',
    );
  }
}
