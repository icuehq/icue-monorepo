import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show AssetStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/assets_table.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:provider/provider.dart';

/// Asset register (FRS 10.19) of the branch.
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
      await context.read<AssetsProvider>().loadAssets(status: _status);
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
    final asset = await assetsProvider.findByCode(code);
    if (!mounted) return;
    if (asset == null) {
      showMessage(context, assetsProvider.errorMessage ?? 'No asset "$code"');
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
    final manage = context.read<InventoryProvider>().access.can(
      'inventory.assets.manage',
    );
    final currentValue = _search.toLowerCase();
    final shown = [
      for (final asset in assetsProvider.assets)
        if (currentValue.isEmpty ||
            asset.id.toLowerCase().contains(currentValue) ||
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
      floatingActionButton: manage && !context.isWide
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Register'),
              onPressed: _register,
            )
          : null,
      body: context.isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AssetsTable(
                assetsProvider: assetsProvider,
                onOpen: _open,
                onReload: _load,
                onRegister: manage ? _register : null,
                onMaintenance: () =>
                    context.push(InventoryRoutes.inventoryMaintenance),
              ),
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        IcueScanField(
                          hint: 'Search or scan asset ID, tag, name or serial',
                          onChanged: (value) =>
                              setState(() => _search = value.trim()),
                          onScan: _scanned,
                        ),
                        DropdownButton<String?>(
                          isExpanded: true,
                          value: _status,
                          items: [
                            const DropdownMenuItem(child: Text('All statuses')),
                            for (final status in AssetStatus.values)
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
                                : Text(
                                    assetsProvider.errorMessage ?? 'No assets',
                                  ),
                          )
                        : IcueAdaptiveList<InventoryAsset>(
                            items: shown,
                            onTap: _open,
                            columns: [
                              IcueAdaptiveColumn.text(
                                'Asset',
                                (asset) => asset.name,
                                flex: 2,
                              ),
                              IcueAdaptiveColumn.text(
                                'ID',
                                (asset) => asset.id,
                              ),
                              IcueAdaptiveColumn.text(
                                'Assigned to',
                                (asset) => asset.assignedTo?.label ?? '—',
                              ),
                              IcueAdaptiveColumn.text(
                                'Location',
                                (asset) => asset.location ?? '—',
                              ),
                              IcueAdaptiveColumn(
                                label: 'Status',
                                cell: (context, asset) =>
                                    StatusChip(asset.status),
                              ),
                            ],
                            cardBuilder: (context, asset) => ListTile(
                              title: Text(asset.name),
                              subtitle: Text(
                                '${asset.id}${asset.assignedTo == null ? '' : ' · ${asset.assignedTo!.label}'}'
                                '${asset.location == null ? '' : ' · ${asset.location}'}',
                              ),
                              trailing: StatusChip(asset.status),
                              onTap: () => _open(asset),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
