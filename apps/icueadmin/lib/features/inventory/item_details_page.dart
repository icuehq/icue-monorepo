import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/variant_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  InventoryItem? _item;
  List<InventoryVariant> _variants = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    final item = await inventoryProvider.item(widget.itemId);
    final variants = await inventoryProvider.variants(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _variants = variants;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final item = _item;
    final canEdit = inventoryProvider.access.can('inventory.items.manage');
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
      ('Category', inventoryProvider.category(item.categoryId)?.name),
      ('Subcategory', inventoryProvider.category(item.subcategoryId)?.name),
      ('Tracking', item.tracking.label),
      ('Stock unit', item.stockUnit),
      for (final purchaseUnit in item.purchaseUnits)
        ('1 ${purchaseUnit.unit}', '${purchaseUnit.factor} ${item.stockUnit}'),
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
          for (final row in rows)
            if (row.$2 != null && row.$2!.isNotEmpty)
              ListTile(
                dense: true,
                title: Text(row.$1),
                trailing: Text(row.$2!),
              ),
          if (canEdit)
            SwitchListTile(
              title: const Text('Active'),
              value: item.active,
              onChanged: (value) async {
                if (await inventoryProvider.setItemActive(
                  item.id,
                  active: value,
                )) {
                  await _load();
                } else if (context.mounted) {
                  showMessage(
                    context,
                    inventoryProvider.errorMessage ?? 'Failed',
                  );
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
            for (final variant in _variants)
              ListTile(
                dense: true,
                title: Text(variant.sku),
                subtitle: Text(
                  variant.attrs.entries
                      .map((mapEntry) => '${mapEntry.key}: ${mapEntry.value}')
                      .join(', '),
                ),
                trailing: variant.active ? null : const InactiveBadge(),
                onTap: canEdit
                    ? () async {
                        if (await VariantDialog.show(
                          context,
                          item,
                          variant: variant,
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
