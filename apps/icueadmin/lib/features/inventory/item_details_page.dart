import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/variant_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  InvItem? _item;
  List<InvVariant> _variants = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = context.read<InventoryProvider>();
    final item = await p.item(widget.itemId);
    final variants = await p.variants(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _variants = variants;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final item = _item;
    final canEdit = p.access.can('inv.items.manage');
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: Center(
          child: _loaded
              ? const Text('Item not found')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final rows = <(String, String?)>[
      ('Code', item.code),
      ('Category', p.category(item.categoryId)?.name),
      ('Subcategory', p.category(item.subcategoryId)?.name),
      ('Tracking', item.tracking.label),
      ('Stock unit', item.stockUnit),
      for (final u in item.purchaseUnits)
        ('1 ${u.unit}', '${u.factor} ${item.stockUnit}'),
      ('Minimum level', item.minLevel?.toString()),
      ('Reorder level', item.reorderLevel?.toString()),
      ('Default price', item.defaultPrice?.toString()),
      ('Storage location', item.defaultLocation),
      ('Description', item.description),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(AppRoutes.inventoryItemForm, extra: item);
                await _load();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          for (final r in rows)
            if (r.$2 != null && r.$2!.isNotEmpty)
              ListTile(dense: true, title: Text(r.$1), trailing: Text(r.$2!)),
          if (canEdit)
            SwitchListTile(
              title: const Text('Active'),
              value: item.active,
              onChanged: (v) async {
                if (await p.setItemActive(item.id, active: v)) {
                  await _load();
                } else if (context.mounted) {
                  invSnack(context, p.errorMessage ?? 'Failed');
                }
              },
            ),
          if (item.variantAttrs.isNotEmpty) ...[
            ListTile(
              title: const Text('Variants'),
              trailing: canEdit
                  ? IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        if (await VariantDialog.show(context, item)) {
                          await _load();
                        }
                      },
                    )
                  : null,
            ),
            for (final v in _variants)
              ListTile(
                dense: true,
                title: Text(v.sku),
                subtitle: Text(
                  v.attrs.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                ),
                trailing: v.active ? null : const InactiveBadge(),
                onTap: canEdit
                    ? () async {
                        if (await VariantDialog.show(
                          context,
                          item,
                          variant: v,
                        )) {
                          await _load();
                        }
                      }
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
