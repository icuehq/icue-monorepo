import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/category_form_sheet.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final canEdit = p.access.can('inv.settings');
    final rows = <(InvCategory, bool)>[
      for (final c in p.topCategories) ...[
        (c, false),
        for (final s in p.categories.where((s) => s.parentId == c.id))
          (s, true),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => CategoryFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Category'),
            )
          : null,
      body: rows.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : const SeedDefaultsButton(),
            )
          : ListView(
              children: [
                for (final (c, isSub) in rows)
                  ListTile(
                    contentPadding: EdgeInsets.only(
                      left: isSub ? 40 : 16,
                      right: 8,
                    ),
                    title: Text(c.name),
                    subtitle: Text('${c.code} · ${c.suggestedTracking.label}'),
                    leading: c.active ? null : const InactiveBadge(),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _onMenu(context, v, c),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'items',
                          child: Text('View items'),
                        ),
                        if (canEdit) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (!isSub)
                            const PopupMenuItem(
                              value: 'sub',
                              child: Text('Add subcategory'),
                            ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(c.active ? 'Deactivate' : 'Activate'),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _onMenu(BuildContext context, String v, InvCategory c) async {
    final p = context.read<InventoryProvider>();
    switch (v) {
      case 'items':
        await context.push('${AppRoutes.inventoryItems}?category=${c.id}');
      case 'edit':
        await CategoryFormSheet.show(context, category: c);
      case 'sub':
        await CategoryFormSheet.show(context, parentId: c.id);
      case 'toggle':
        if (!await p.setCategoryActive(c.id, active: !c.active) &&
            context.mounted) {
          invSnack(context, p.errorMessage ?? 'Failed');
        }
    }
  }
}
