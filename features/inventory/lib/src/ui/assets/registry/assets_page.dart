import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_sheet.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:provider/provider.dart';

/// Asset register (FRS 10.19) on the caller's campuses.
class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  String? _status;
  var _search = '';

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      await context.read<AssetsProvider>().loadAssets(
        inventoryProvider.access,
        status: _status,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// A scan opens the asset with that ID or RFID tag, even outside the loaded list.
  Future<void> _scanned(String code) async {
    final assetsProvider = context.read<AssetsProvider>();
    final asset = await assetsProvider.findByCode(
      context.read<InventoryProvider>().access,
      code,
    );
    if (!mounted) return;
    if (asset == null) {
      showMessage(context, assetsProvider.errorMessage ?? 'No asset "$code"');
      return;
    }
    await showFormSheet(context, () => AssetSheet(asset: asset));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inventory.assets.manage',
    );
    final currentValue = _search.toLowerCase();
    final shown = [
      for (final asset in assetsProvider.assets)
        if (currentValue.isEmpty ||
            asset.assetId.toLowerCase().contains(currentValue) ||
            asset.name.toLowerCase().contains(currentValue) ||
            (asset.serialNumber ?? '').toLowerCase().contains(currentValue) ||
            (asset.rfidTag ?? '').toLowerCase().contains(currentValue))
          asset,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: [
          IconButton(
            tooltip: 'Maintenance',
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: () => context.push(InventoryRoutes.inventoryMaintenance),
          ),
        ],
      ),
      floatingActionButton: manage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Register'),
              onPressed: () async {
                await context.push(InventoryRoutes.inventoryAssetForm);
                if (mounted) await _load();
              },
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                ScanField(
                  hint: 'Search or scan asset ID, tag, name or serial',
                  onChanged: (value) => setState(() => _search = value.trim()),
                  onScan: _scanned,
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: _status,
                  items: [
                    const DropdownMenuItem(child: Text('All statuses')),
                    for (final status in InventoryAsset.statuses)
                      DropdownMenuItem(
                        value: status,
                        child: Text(humanizeStatus(status)),
                      ),
                  ],
                  onChanged: (value) {
                    _status = value;
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: assetsProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(assetsProvider.errorMessage ?? 'No assets'),
                  )
                : ListView(
                    children: [
                      for (final asset in shown)
                        ListTile(
                          title: Text(asset.name),
                          subtitle: Text(
                            '${asset.assetId}${asset.assignedTo == null ? '' : ' · ${asset.assignedTo!.label}'}'
                            '${asset.location == null ? '' : ' · ${asset.location}'}',
                          ),
                          trailing: StatusChip(asset.status),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => AssetSheet(asset: asset),
                            );
                            if (mounted) await _load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
