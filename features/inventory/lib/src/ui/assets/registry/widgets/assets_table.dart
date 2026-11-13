import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show AssetStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';

/// Wide-screen asset register: an [IcueClientTable] over the assets loaded by [AssetsProvider].
class AssetsTable extends StatelessWidget {
  const AssetsTable({
    required this.assetsProvider,
    required this.onOpen,
    required this.onReload,
    this.onRegister,
    this.onMaintenance,
    super.key,
  });

  final AssetsProvider assetsProvider;
  final void Function(InventoryAsset asset) onOpen;
  final VoidCallback onReload;

  /// Null hides the Register button (no manage permission).
  final VoidCallback? onRegister;
  final VoidCallback? onMaintenance;

  @override
  Widget build(BuildContext context) {
    final assets = assetsProvider.assets;
    final register = onRegister == null
        ? null
        : IcueTableAction(
            label: 'Register',
            icon: Icons.add_rounded,
            onPressed: onRegister,
          );
    return IcueClientTable<InventoryAsset>(
      title: 'Assets',
      items: assets,
      rowKey: (asset) => asset.id,
      rowLabel: (asset) => asset.name,
      status: IcueTableStatus.of(
        failed: assetsProvider.errorMessage != null && assets.isEmpty,
        loading: assetsProvider.isLoading && assets.isEmpty,
      ),
      errorMessage: assetsProvider.errorMessage,
      onRetry: onReload,
      initialPageSize: 25,
      searchHint: 'Search asset ID, tag, name or serial...',
      searchText: (asset) =>
          '${asset.assetId} ${asset.name} ${asset.serialNumber ?? ''} '
          '${asset.rfidTag ?? ''}',
      filters: [
        IcueClientFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final status in AssetStatus.values)
              IcueTableFilterOption(status, humanizeStatus(status)),
          ],
          matches: (asset, status) => asset.status == status,
        ),
      ],
      onRowTap: onOpen,
      primaryAction: register,
      secondaryAction: onMaintenance == null
          ? null
          : IcueTableAction(
              label: 'Maintenance',
              icon: Icons.build_circle_outlined,
              onPressed: onMaintenance,
            ),
      emptyTitle: 'No assets registered',
      emptyMessage: 'Register an asset to track who has it and its condition.',
      emptyAction: register,
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Asset',
          flex: 3,
          minWidth: 200,
          hideable: false,
          sortable: true,
          comparator: (asset) => asset.name.toLowerCase(),
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.name,
            subtitle: [
              asset.make,
              asset.model,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
          ),
        ),
        IcueTableColumn(
          id: 'assetId',
          label: 'ID',
          flex: 2,
          sortable: true,
          comparator: (asset) => asset.assetId,
          cellBuilder: (context, asset) =>
              IcueTableCellText(asset.assetId, subtitle: asset.serialNumber),
        ),
        IcueTableColumn(
          id: 'assignedTo',
          label: 'Assigned to',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.assignedTo?.label ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'location',
          label: 'Location',
          flex: 2,
          hideBelowWidth: 1000,
          cellBuilder: (context, asset) => IcueTableCellText(
            asset.location ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'condition',
          label: 'Condition',
          hideBelowWidth: 1100,
          cellBuilder: (context, asset) => IcueTableCellText(
            humanizeStatus(asset.condition),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          cellBuilder: (context, asset) => IcueStatusPill(
            label: humanizeStatus(asset.status),
            color: statusColor(asset.status),
            compact: true,
          ),
        ),
      ],
    );
  }
}
