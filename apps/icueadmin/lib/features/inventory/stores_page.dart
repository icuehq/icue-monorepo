import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/store_form_sheet.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => StoreFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Store'),
            )
          : null,
      body: inventoryProvider.stores.isEmpty
          ? Center(
              child: Text(
                inventoryProvider.isLoading ? 'Loading…' : 'No stores yet',
              ),
            )
          : ListView(
              children: [
                for (final store in inventoryProvider.stores)
                  ListTile(
                    title: Text(store.name),
                    subtitle: Text(
                      '${store.code} · Campus ${store.campusId}'
                      '${store.location == null ? '' : ' · ${store.location}'}',
                    ),
                    leading: store.active ? null : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await StoreFormSheet.show(
                                  context,
                                  store: store,
                                );
                              } else if (!await inventoryProvider
                                      .setStoreActive(
                                        store.id,
                                        active: !store.active,
                                      ) &&
                                  context.mounted) {
                                showMessage(
                                  context,
                                  inventoryProvider.errorMessage ?? 'Failed',
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  store.active ? 'Deactivate' : 'Activate',
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
