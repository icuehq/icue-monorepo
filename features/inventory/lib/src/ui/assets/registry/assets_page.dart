import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show AssetStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:provider/provider.dart';

/// Asset register (FRS 10.19) of the branch.
class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  static final _statuses = {
    for (final status in AssetStatus.values) status: humanizeStatus(status),
  };

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) await context.read<AssetsProvider>().assetList.load();
  }

  /// Typing searches by asset name (prefix, as written) after a short pause.
  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => context.read<AssetsProvider>().assetList.setSearch(value),
    );
  }

  /// A scan opens the asset with that ID or RFID tag, even outside the loaded list.
  Future<void> _scanned(String code) async {
    final assetsProvider = context.read<AssetsProvider>();
    final asset = await assetsProvider.findByCode(code);
    if (!mounted) return;
    if (asset == null) {
      IcueToast.error(
        context,
        assetsProvider.errorMessage ?? 'No asset "$code"',
      );
      return;
    }
    await _open(asset);
  }

  Future<void> _open(InventoryAsset asset) async {
    await context.push(
      '${InventoryRoutes.inventoryAssetDetails}?id=${asset.id}',
    );
    if (mounted) await _load();
  }

  Future<void> _register() async {
    await context.push(InventoryRoutes.inventoryAssetForm);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    return PagedListPage<InventoryAsset>(
      title: 'Assets',
      state: assetsProvider.assetList,
      statuses: _statuses,
      emptyIcon: Icons.inventory_2_outlined,
      emptyMessage: 'Register an asset to track who has it and its condition.',
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: 'Maintenance',
          icon: const Icon(Icons.build_circle_outlined),
          onPressed: () => context.push(InventoryRoutes.inventoryMaintenance),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Register'),
        onPressed: _register,
      ),
      header: IcueScanField(
        hint: 'Search by name, or scan asset ID or tag',
        onChanged: _typed,
        onScan: _scanned,
      ),
      itemCard: (context, asset) => ListTile(
        title: Text(asset.name),
        subtitle: Text(
          '${asset.id}${asset.assignedTo == null ? '' : ' · ${asset.assignedTo!.label}'}'
          '${asset.location == null ? '' : ' · ${asset.location}'}',
        ),
        trailing: InventoryStatusChip(asset.status),
        onTap: () => _open(asset),
      ),
      table: PagedListTable<InventoryAsset>(
        title: 'Assets',
        state: assetsProvider.assetList,
        statuses: _statuses,
        searchHint: 'Asset name (starts with)',
        rowKey: (asset) => asset.id,
        rowLabel: (asset) => asset.name,
        onOpen: _open,
        emptyMessage:
            'Register an asset to track who has it and its condition.',
        primaryAction: IcueTableAction(
          label: 'Register',
          icon: Icons.add_rounded,
          onPressed: _register,
        ),
        secondaryAction: IcueTableAction(
          label: 'Maintenance',
          icon: Icons.build_circle_outlined,
          onPressed: () => context.push(InventoryRoutes.inventoryMaintenance),
        ),
        columns: [
          IcueTableColumn(
            id: 'name',
            label: 'Asset',
            flex: 3,
            minWidth: 200,
            cellBuilder: (context, asset) => IcueTableCellText(
              asset.name,
              subtitle: [
                asset.make,
                asset.model,
              ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
            ),
          ),
          IcueTableColumn(
            id: 'id',
            label: 'ID',
            flex: 2,
            cellBuilder: (context, asset) =>
                IcueTableCellText(asset.id, subtitle: asset.serialNumber),
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
              color: inventoryStatusColor(asset.status),
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}
