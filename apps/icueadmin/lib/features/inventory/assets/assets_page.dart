import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/assets/asset_sheet.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
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
    final inv = context.read<InventoryProvider>();
    if (inv.categories.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<AssetsProvider>().loadAssets(
        inv.access,
        status: _status,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inv.assets.manage',
    );
    final q = _search.toLowerCase();
    final shown = [
      for (final a in p.assets)
        if (q.isEmpty ||
            a.assetId.toLowerCase().contains(q) ||
            a.name.toLowerCase().contains(q) ||
            (a.serialNo ?? '').toLowerCase().contains(q))
          a,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: [
          IconButton(
            tooltip: 'Maintenance',
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: () => context.push(AppRoutes.inventoryMaintenance),
          ),
        ],
      ),
      floatingActionButton: manage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Register'),
              onPressed: () async {
                await context.push(AppRoutes.inventoryAssetForm);
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
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search asset ID, name or serial',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: _status,
                  items: [
                    const DropdownMenuItem(child: Text('All statuses')),
                    for (final s in InvAsset.statuses)
                      DropdownMenuItem(value: s, child: Text(statusLabel(s))),
                  ],
                  onChanged: (v) {
                    _status = v;
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No assets'),
                  )
                : ListView(
                    children: [
                      for (final a in shown)
                        ListTile(
                          title: Text(a.name),
                          subtitle: Text(
                            '${a.assetId}${a.assignedTo == null ? '' : ' · ${a.assignedTo!.label}'}'
                            '${a.location == null ? '' : ' · ${a.location}'}',
                          ),
                          trailing: StatusChip(a.status),
                          onTap: () async {
                            await showInvSheet(
                              context,
                              () => AssetSheet(asset: a),
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
