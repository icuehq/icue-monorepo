import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/store_form_sheet.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final canEdit = p.access.can('inv.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => StoreFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Store'),
            )
          : null,
      body: p.stores.isEmpty
          ? Center(child: Text(p.isLoading ? 'Loading…' : 'No stores yet'))
          : ListView(
              children: [
                for (final s in p.stores)
                  ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.code} · Campus ${s.campusId}'
                      '${s.location == null ? '' : ' · ${s.location}'}',
                    ),
                    leading: s.active ? null : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await StoreFormSheet.show(context, store: s);
                              } else if (!await p.setStoreActive(
                                    s.id,
                                    active: !s.active,
                                  ) &&
                                  context.mounted) {
                                invSnack(context, p.errorMessage ?? 'Failed');
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
                                  s.active ? 'Deactivate' : 'Activate',
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
