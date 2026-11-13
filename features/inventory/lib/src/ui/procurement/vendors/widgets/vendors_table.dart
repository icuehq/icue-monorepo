import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Wide-screen vendor directory: an [IcueClientTable] over the vendors loaded by [ProcurementProvider].
class VendorsTable extends StatelessWidget {
  const VendorsTable({
    required this.vendors,
    required this.categories,
    required this.loading,
    required this.errorMessage,
    required this.onOpen,
    required this.onReload,
    this.onCreate,
    this.onEdit,
    this.onToggleActive,
    super.key,
  });

  final List<InventoryVendor> vendors;
  final List<InventoryCategory> categories;

  /// True until the first fetch ends.
  final bool loading;
  final String? errorMessage;
  final void Function(InventoryVendor vendor) onOpen;
  final VoidCallback onReload;

  /// Null hides the New vendor button and the row actions (no manage permission).
  final VoidCallback? onCreate;
  final void Function(InventoryVendor vendor)? onEdit;
  final void Function(InventoryVendor vendor)? onToggleActive;

  String _categoryNames(InventoryVendor vendor) => [
    for (final id in vendor.categoryIds)
      categories.where((category) => category.id == id).firstOrNull?.name ?? id,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final create = onCreate == null
        ? null
        : IcueTableAction(
            label: 'New vendor',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          );
    final usedCategories = [
      for (final category in categories)
        if (vendors.any((vendor) => vendor.categoryIds.contains(category.id)))
          category,
    ];
    return IcueClientTable<InventoryVendor>(
      title: 'Vendors',
      items: vendors,
      rowKey: (vendor) => vendor.id,
      rowLabel: (vendor) => vendor.name,
      status: IcueTableStatus.of(
        failed: errorMessage != null && vendors.isEmpty,
        loading: loading,
      ),
      errorMessage: errorMessage,
      onRetry: onReload,
      initialPageSize: 25,
      searchHint: 'Search name, contact, phone, email or GST...',
      searchText: (vendor) =>
          '${vendor.name} ${vendor.contactPerson ?? ''} '
          '${vendor.phone ?? ''} ${vendor.email ?? ''} '
          '${vendor.taxNumber ?? ''}',
      filters: [
        IcueClientFilter<InventoryVendor>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (vendor, status) => vendor.active == (status == 'active'),
        ),
        if (usedCategories.isNotEmpty)
          IcueClientFilter<InventoryVendor>(
            id: 'category',
            label: 'Category',
            options: [
              for (final category in usedCategories)
                IcueTableFilterOption(category.id, category.name),
            ],
            matches: (vendor, id) => vendor.categoryIds.contains(id),
          ),
      ],
      onRowTap: onOpen,
      primaryAction: create,
      emptyTitle: 'No vendors yet',
      emptyMessage: create == null
          ? 'Vendors will appear here once added.'
          : 'Add trusted suppliers to issue quotations and purchase orders.',
      emptyAction: create,
      rowActions: onEdit == null || onToggleActive == null
          ? null
          : (vendor) => [
              IcueTableRowAction<InventoryVendor>(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: onEdit!,
              ),
              IcueTableRowAction<InventoryVendor>(
                label: vendor.active ? 'Deactivate' : 'Activate',
                icon: vendor.active
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                destructive: vendor.active,
                onPressed: onToggleActive!,
              ),
            ],
      columns: [
        IcueTableColumn<InventoryVendor>(
          id: 'name',
          label: 'Vendor',
          flex: 3,
          minWidth: 200,
          hideable: false,
          sortable: true,
          comparator: (vendor) => vendor.name.toLowerCase(),
          cellBuilder: (context, vendor) => IcueTableCellText(
            vendor.name,
            subtitle: vendor.taxNumber == null
                ? null
                : 'GST ${vendor.taxNumber}',
          ),
        ),
        IcueTableColumn<InventoryVendor>(
          id: 'contact',
          label: 'Contact',
          flex: 2,
          sortable: true,
          comparator: (vendor) => (vendor.contactPerson ?? '').toLowerCase(),
          cellBuilder: (context, vendor) => IcueTableCellText(
            vendor.contactPerson ?? '—',
            subtitle: vendor.phone,
          ),
        ),
        IcueTableColumn<InventoryVendor>(
          id: 'email',
          label: 'Email',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, vendor) => IcueTableCellText(
            vendor.email ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn<InventoryVendor>(
          id: 'categories',
          label: 'Categories',
          flex: 2,
          hideBelowWidth: 1000,
          cellBuilder: (context, vendor) => IcueTableCellText(
            vendor.categoryIds.isEmpty ? '—' : _categoryNames(vendor),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn<InventoryVendor>(
          id: 'status',
          label: 'Status',
          cellBuilder: (context, vendor) => IcueStatusPill(
            label: vendor.active ? 'Active' : 'Inactive',
            color: vendor.active ? Colors.green : Colors.grey,
            compact: true,
          ),
        ),
      ],
    );
  }
}
