import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_cards.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';

List<IcueTableFilter> _storeTableFilters(
  AssetsProvider assetsProvider,
  InventoryProvider inventoryProvider,
) => [
  if (inventoryProvider.showStoreFilter)
    IcueTableFilter(
      id: 'store',
      label: 'Store',
      options: [
        for (final store in inventoryProvider.stores)
          IcueTableFilterOption(store.id, store.name),
      ],
      value: assetsProvider.storeId,
      onChanged: assetsProvider.setStore,
    ),
];

/// Wide-screen table of registered assets.
class RegisteredAssetsTable extends StatelessWidget {
  const RegisteredAssetsTable({
    required this.assetsProvider,
    required this.inventoryProvider,
    required this.statuses,
    required this.storeName,
    required this.onOpen,
    required this.onClearFilters,
    required this.onScan,
    required this.onRefresh,
    super.key,
  });

  final AssetsProvider assetsProvider;
  final InventoryProvider inventoryProvider;
  final Map<String, String> statuses;
  final String Function(String storeId) storeName;
  final ValueChanged<InventoryAsset> onOpen;
  final Future<void> Function() onClearFilters;
  final VoidCallback onScan;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    const empty =
        'No registered assets yet. Receive stock of an asset item, then '
        'register each unit from the Unregistered tab.';
    return PagedListTable<InventoryAsset>(
      title: 'Registered assets',
      state: assetsProvider.assetList,
      statuses: statuses,
      searchHint: 'Asset name (starts with)',
      rowKey: (asset) => asset.id,
      rowLabel: (asset) => asset.name,
      onOpen: onOpen,
      emptyMessage: empty,
      extraFilters: _storeTableFilters(assetsProvider, inventoryProvider),
      extraFiltered: assetsProvider.storeId != null,
      onClearFilters: onClearFilters,
      primaryAction: IcueTableAction(
        label: 'Scan ID / Tag',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: onScan,
      ),
      secondaryAction: IcueTableAction(
        label: 'Refresh',
        icon: Icons.refresh_rounded,
        onPressed: onRefresh,
      ),
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Asset',
          flex: 3,
          minWidth: 200,
          hideable: false,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.name,
            subtitle: assetSubtitle(
              asset,
              assetsProvider.items[asset.itemId]?.name,
            ),
          ),
        ),
        IcueTableColumn(
          id: 'id',
          label: 'ID / Tag',
          flex: 2,
          minWidth: 160,
          cellBuilder: (context, asset) {
            final details = [
              if (asset.serialNumber != null && asset.serialNumber!.isNotEmpty)
                'S/N ${asset.serialNumber!}',
              if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                'RFID ${asset.rfidTag!}',
            ].join(' · ');
            return IcueTableCellText(asset.id, subtitle: details);
          },
        ),
        if (inventoryProvider.showStoreFilter)
          IcueTableColumn(
            id: 'store',
            label: 'Store',
            flex: 2,
            hideBelowWidth: 1000,
            cellBuilder: (context, asset) => IcueTableCellText(
              storeName(asset.storeId),
              style: IcueTableStyle.of(context).secondary,
            ),
          ),
        IcueTableColumn(
          id: 'assignedTo',
          label: 'Assigned to',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.assignedTo == null
                ? 'In store'
                : formatCustodian(asset.assignedTo!),
            style: asset.assignedTo == null
                ? IcueTableStyle.of(context).muted
                : IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'condition',
          label: 'Condition',
          hideBelowWidth: 1150,
          cellBuilder: (context, asset) => IcueTableCellText(
            humanizeStatus(asset.condition),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          minWidth: 130,
          cellBuilder: (context, asset) => InventoryStatusChip(asset.status),
        ),
      ],
    );
  }
}

/// Wide-screen table of received asset units awaiting registration.
class UnregisteredAssetsTable extends StatelessWidget {
  const UnregisteredAssetsTable({
    required this.assetsProvider,
    required this.inventoryProvider,
    required this.storeName,
    required this.onOpen,
    required this.onClearFilters,
    required this.onScan,
    required this.onRefresh,
    super.key,
  });

  final AssetsProvider assetsProvider;
  final InventoryProvider inventoryProvider;
  final String Function(String storeId) storeName;
  final ValueChanged<InventoryAsset> onOpen;
  final Future<void> Function() onClearFilters;
  final VoidCallback onScan;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    const empty = 'Every received asset is registered.';
    return PagedListTable<InventoryAsset>(
      title: 'Unregistered assets',
      state: assetsProvider.unregisteredList,
      statuses: const {},
      searchHint: 'Asset or item name',
      rowKey: (asset) => asset.id,
      rowLabel: (asset) => asset.name,
      onOpen: onOpen,
      emptyMessage: empty,
      extraFilters: _storeTableFilters(assetsProvider, inventoryProvider),
      extraFiltered: assetsProvider.storeId != null,
      onClearFilters: onClearFilters,
      primaryAction: IcueTableAction(
        label: 'Scan ID / Tag',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: onScan,
      ),
      secondaryAction: IcueTableAction(
        label: 'Refresh',
        icon: Icons.refresh_rounded,
        onPressed: onRefresh,
      ),
      rowActions: (asset) => [
        IcueTableRowAction(
          label: 'Register',
          icon: Icons.app_registration_rounded,
          inline: true,
          variant: IcueButtonVariant.outline,
          onPressed: onOpen,
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Asset',
          flex: 3,
          minWidth: 200,
          hideable: false,
          cellBuilder: (context, asset) {
            final subtitle = assetSubtitle(
              asset,
              assetsProvider.items[asset.itemId]?.name,
            );
            return IcueTableCellText(
              asset.name,
              subtitle: subtitle.isEmpty ? null : subtitle,
            );
          },
        ),
        IcueTableColumn(
          id: 'store',
          label: 'Store',
          flex: 2,
          cellBuilder: (context, asset) =>
              IcueTableCellText(storeName(asset.storeId)),
        ),
        IcueTableColumn(
          id: 'received',
          label: 'Received',
          hideBelowWidth: 900,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.receivedDate?.toDisplayDay() ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'cost',
          label: 'Cost',
          hideBelowWidth: 1100,
          alignment: Alignment.centerRight,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.price?.toRupees() ?? '—',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
      ],
    );
  }
}
