import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/stores/widgets/store_card.dart';
import 'package:inventory/src/ui/masters/stores/widgets/store_dialog.dart';
import 'package:inventory/src/ui/masters/stores/widgets/stores_table.dart';
import 'package:provider/provider.dart';

/// Stores: a table on wide screens, searchable cards on phones.
class StoresPage extends StatefulWidget {
  const StoresPage({super.key});

  @override
  State<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.stores.isEmpty) {
        await inventoryProvider.loadMasters();
      }
    });
  }

  Future<void> _toggleActive(BuildContext context, InventoryStore store) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.setStoreActive(
      store.id,
      active: !store.active,
    );
    if (!success && context.mounted) {
      showMessage(
        context,
        inventoryProvider.errorMessage ?? 'Failed to update store status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    final allStores = inventoryProvider.stores;
    final wide = context.isWide;

    final query = _searchQuery.toLowerCase();
    final filteredStores = [
      for (final store in allStores)
        if ('${store.name} ${store.location ?? ''} ${store.description ?? ''}'
            .toLowerCase()
            .contains(query))
          store,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      floatingActionButton: !wide && canEdit
          ? FloatingActionButton.extended(
              onPressed: () => StoreDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add store'),
            )
          : null,
      body: inventoryProvider.isLoading && allStores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : wide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: StoresTable(
                stores: allStores,
                canEdit: canEdit,
                onToggleActive: (store) => _toggleActive(context, store),
              ),
            )
          : RefreshIndicator(
              onRefresh: inventoryProvider.loadMasters,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SearchBar(
                      hintText: 'Search stores by name or location…',
                      leading: const Icon(Icons.search, size: 20),
                      elevation: const WidgetStatePropertyAll(0),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                    ),
                  ),
                  Expanded(
                    child: filteredStores.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(48),
                                child: Center(
                                  child: Text(
                                    allStores.isEmpty
                                        ? 'No stores yet'
                                        : 'No matching stores',
                                  ),
                                ),
                              ),
                            ],
                          )
                        : IcueAdaptiveCardList(
                            padding: const EdgeInsets.all(12),
                            spacing: 8,
                            itemCount: filteredStores.length,
                            itemBuilder: (context, index) => StoreCard(
                              store: filteredStores[index],
                              canEdit: canEdit,
                              onEdit: (store) =>
                                  StoreDialog.show(context, store: store),
                              onToggleActive: (store) =>
                                  _toggleActive(context, store),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
