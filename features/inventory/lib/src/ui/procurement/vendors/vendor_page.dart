import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/vendors/vendor_actions.dart';
import 'package:provider/provider.dart';

/// Everything known about one vendor, with edit and (de)activate.
class VendorPage extends StatelessWidget {
  const VendorPage({required this.vendorId, super.key});

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendor = context
        .watch<ProcurementProvider>()
        .vendors
        .where((candidate) => candidate.id == vendorId)
        .firstOrNull;
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.vendors.manage');

    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor')),
        body: const Center(child: Text('Vendor not found')),
      );
    }

    final categoryNames = [
      for (final categoryId in vendor.categoryIds)
        inventoryProvider.categories
                .where((category) => category.id == categoryId)
                .firstOrNull
                ?.name ??
            categoryId,
    ];

    Widget row(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(value),
        subtitle: Text(label),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: 'Copy',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) showMessage(context, '$label copied');
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(vendor.name)),
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Chip(
                  label: Text(vendor.active ? 'Active' : 'Inactive'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: vendor.active
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.errorContainer,
                ),
              ],
            ),
            if (!vendor.active)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Inactive vendors cannot be chosen on new quotations or orders.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            row(
              Icons.person_outline_rounded,
              'Contact person',
              vendor.contactPerson,
            ),
            row(Icons.phone_outlined, 'Phone', vendor.phone),
            row(Icons.email_outlined, 'Email', vendor.email),
            row(Icons.language_rounded, 'Website', vendor.website),
            row(Icons.location_on_outlined, 'Address', vendor.address),
            row(Icons.receipt_long_outlined, 'GST / Tax ID', vendor.taxNumber),
            row(Icons.notes_rounded, 'Remarks', vendor.remarks),
            if (categoryNames.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Supplied categories',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final name in categoryNames) Chip(label: Text(name)),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: canEdit
          ? Material(
              elevation: 8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: vendor.active ? 'Deactivate' : 'Activate',
                          onPressed: () => toggleVendorActive(context, vendor),
                          variant: AppButtonVariant.outline,
                          leadingIcon: vendor.active
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Edit',
                          onPressed: () => context.push(
                            '${InventoryRoutes.inventoryVendorForm}?id=${vendor.id}',
                          ),
                          leadingIcon: Icons.edit_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
