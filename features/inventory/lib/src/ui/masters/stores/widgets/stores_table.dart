import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/stores/widgets/store_dialog.dart';

/// Wide-screen stores list: an [IcueClientTable] over the loaded stores.
class StoresTable extends StatelessWidget {
  const StoresTable({
    required this.stores,
    required this.canEdit,
    required this.onToggleActive,
    super.key,
  });

  final List<InventoryStore> stores;
  final bool canEdit;
  final void Function(InventoryStore store) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final campusIds = {for (final store in stores) store.campusId}.toList()
      ..sort();

    return IcueClientTable<InventoryStore>(
      title: 'Stores',
      items: stores,
      rowKey: (store) => store.id,
      rowLabel: (store) => store.name,
      searchHint: 'Search name, location or description...',
      searchText: (store) =>
          '${store.name} ${store.location ?? ''} ${store.description ?? ''}',
      onRowTap: canEdit
          ? (store) => StoreDialog.show(context, store: store)
          : null,
      primaryAction: canEdit
          ? IcueTableAction(
              label: 'Store',
              icon: Icons.add_rounded,
              onPressed: () => StoreDialog.show(context),
            )
          : null,
      emptyTitle: 'No stores yet',
      emptyMessage: 'Create stores to organize and track physical inventory across campuses.',
      emptyAction: canEdit
          ? IcueTableAction(
              label: 'Add store',
              icon: Icons.add_rounded,
              onPressed: () => StoreDialog.show(context),
            )
          : null,
      filters: [
        IcueClientFilter<InventoryStore>(
          id: 'campus',
          label: 'Campus',
          options: [
            for (final campusId in campusIds)
              IcueTableFilterOption('$campusId', 'Campus $campusId'),
          ],
          matches: (store, optionId) => '${store.campusId}' == optionId,
        ),
        IcueClientFilter<InventoryStore>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (store, optionId) => (optionId == 'active') == store.active,
        ),
      ],
      rowActions: (store) => canEdit
          ? [
              IcueTableRowAction(
                label: 'Edit',
                icon: Icons.edit_outlined,
                inline: true,
                onPressed: (row) => StoreDialog.show(context, store: row),
              ),
              IcueTableRowAction(
                label: store.active ? 'Deactivate' : 'Activate',
                icon: store.active
                    ? Icons.block_outlined
                    : Icons.check_circle_outline_rounded,
                inline: true,
                onPressed: onToggleActive,
              ),
            ]
          : const [],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Store',
          flex: 3,
          minWidth: 200,
          sortable: true,
          comparator: (store) => store.name.toLowerCase(),
          hideable: false,
          cellBuilder: (context, store) => IcueTableCellText(
            store.name,
            leading: store.active ? null : const IcueInactiveBadge(),
          ),
        ),
        IcueTableColumn(
          id: 'campus',
          label: 'Campus',
          sortable: true,
          comparator: (store) => store.campusId,
          cellBuilder: (context, store) => IcueTableCellText(
            'Campus ${store.campusId}',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'location',
          label: 'Location',
          flex: 2,
          cellBuilder: (context, store) => IcueTableCellText(
            store.location ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'description',
          label: 'Description',
          flex: 3,
          hideBelowWidth: 900,
          cellBuilder: (context, store) => IcueTableCellText(
            store.description ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'storekeepers',
          label: 'Storekeepers',
          sortable: true,
          comparator: (store) => store.storekeeperIds.length,
          alignment: Alignment.centerRight,
          cellBuilder: (context, store) => IcueTableCellText(
            '${store.storekeeperIds.length}',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
      ],
    );
  }
}
