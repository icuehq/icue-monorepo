import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_action_dialog.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_custody_card.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_details_header.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_specs_card.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_stat_tile.dart';
import 'package:provider/provider.dart';

/// One asset on its own page: details, actions, custody history and timeline (FRS 10.19).
class AssetDetailsPage extends StatefulWidget {
  const AssetDetailsPage({required this.assetId, super.key});

  final String assetId;

  @override
  State<AssetDetailsPage> createState() => _AssetDetailsPageState();
}

class _AssetDetailsPageState extends State<AssetDetailsPage> {
  InventoryAsset? _asset;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final assetsProvider = context.read<AssetsProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    final asset = await assetsProvider.asset(widget.assetId);
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _loaded = true;
    });
    if (asset == null) return;
    await assetsProvider.loadItemNames([asset.itemId]);
    if (mounted) await assetsProvider.loadDetail(asset.id);
  }

  /// Opens an action form, then reloads so the page shows the new status.
  Future<void> _act(Widget Function() form) async {
    await showDialog<void>(context: context, builder: (_) => form());
    if (mounted) await _load();
  }

  List<(String, IconData, Widget Function())> _actions(
    InventoryAsset asset,
  ) => [
    if (!asset.isRetired && !asset.inMaintenance && asset.status == 'available')
      (
        'Assign',
        Icons.person_add_alt_1_outlined,
        () => AssetActionDialog(asset: asset, action: AssetAction.assign),
      ),
    if (!asset.isRetired &&
        !asset.inMaintenance &&
        asset.status == 'assigned') ...[
      (
        'Transfer',
        Icons.swap_horiz_rounded,
        () => AssetActionDialog(asset: asset, action: AssetAction.transfer),
      ),
      (
        'Return',
        Icons.assignment_return_outlined,
        () => AssetActionDialog(asset: asset, action: AssetAction.giveBack),
      ),
    ],
    if (!asset.isRetired)
      (
        'Condition',
        Icons.fact_check_outlined,
        () => AssetActionDialog(asset: asset, action: AssetAction.condition),
      ),
    if (!asset.isRetired && !asset.inMaintenance && asset.status != 'assigned')
      (
        'Retire',
        Icons.archive_outlined,
        () => AssetActionDialog(asset: asset, action: AssetAction.retire),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final assetsProvider = context.watch<AssetsProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();

    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Asset details')),
        body: Center(
          child: _loaded
              ? Text(assetsProvider.errorMessage ?? 'Asset not found')
              : const CircularProgressIndicator(),
        ),
      );
    }

    final itemName = assetsProvider.items[asset.itemId]?.name;
    final store = inventoryProvider.stores
        .where((entry) => entry.id == asset.storeId)
        .firstOrNull;
    final actions = _actions(asset);

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name.isNotEmpty ? asset.name : 'Asset details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTwoColumn = width >= 960;
          final padding = width >= 900 ? 24.0 : 16.0;
          final statColumns = width >= 1200 ? 6 : (width >= 640 ? 3 : 2);
          final statTileWidth =
              (width - (padding * 2) - (12 * (statColumns - 1))) / statColumns;

          final statTiles = [
            (
              'Status',
              humanizeStatus(asset.status),
              Icons.info_outline_rounded,
              asset.inMaintenance || asset.status == 'damaged',
            ),
            (
              'Condition',
              humanizeStatus(asset.condition),
              Icons.verified_outlined,
              asset.condition == 'damaged' || asset.condition == 'poor',
            ),
            (
              'Custodian',
              asset.assignedTo?.label ?? 'In Store',
              Icons.person_outline_rounded,
              false,
            ),
            ('Store', store?.name ?? '—', Icons.storefront_outlined, false),
            (
              'Asset Value',
              asset.price?.toRupees() ?? '—',
              Icons.payments_outlined,
              false,
            ),
            (
              'Next Service',
              asset.nextServiceDate?.toDisplayDay() ?? 'None',
              Icons.build_outlined,
              false,
            ),
          ];

          final headerCard = AssetDetailsHeader(
            asset: asset,
            itemName: itemName,
            storeName: store?.name,
            actions: actions,
            onAct: _act,
          );

          final specsCard = AssetSpecsCard(
            asset: asset,
            itemName: itemName,
            storeName: store?.name,
          );

          final financialCard = AssetFinancialCard(asset: asset);

          final custodyCard = AssetCustodyCard(
            asset: asset,
            assetsProvider: assetsProvider,
          );

          final historyCard = AssetHistoryCard(assetsProvider: assetsProvider);

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.all(padding),
              children: [
                headerCard,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (label, value, icon, highlight) in statTiles)
                      AssetStatTile(
                        width: statTileWidth,
                        label: label,
                        value: value,
                        icon: icon,
                        highlight: highlight,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isTwoColumn)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            specsCard,
                            const SizedBox(height: 16),
                            financialCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            custodyCard,
                            const SizedBox(height: 16),
                            historyCard,
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  specsCard,
                  const SizedBox(height: 16),
                  financialCard,
                  const SizedBox(height: 16),
                  custodyCard,
                  const SizedBox(height: 16),
                  historyCard,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
