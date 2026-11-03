import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

typedef PickedItem = ({InventoryItem item, InventoryVariant? variant});

/// Search-and-pick dialog for stock lines. Asset-tracked items are managed in Assets, so they are hidden
/// unless [assets] (purchase requests can ask for them).
Future<PickedItem?> pickItem(
  BuildContext context, {
  bool assets = false,
}) async {
  final inventoryProvider = context.read<InventoryProvider>();
  await inventoryProvider.loadItems(search: '', clearCategory: true);
  if (!context.mounted) return null;
  final item = await showDialog<InventoryItem>(
    context: context,
    builder: (_) => _PickerDialog(assets: assets),
  );
  if (item == null || !context.mounted) {
    return item == null ? null : (item: item, variant: null);
  }
  final variants = (await inventoryProvider.variants(item.id))
      .where((variant) => variant.active)
      .toList();
  if (!context.mounted) return null;
  // Items without variants are stocked directly; the backend rejects a missing variant when one is required.
  if (variants.isEmpty) return (item: item, variant: null);
  final currentVariant = await showDialog<InventoryVariant>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('${item.name} – variant'),
      children: [
        for (final variant in variants)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, variant),
            child: Text('${variant.sku} · ${variant.attrs.values.join(' / ')}'),
          ),
      ],
    ),
  );
  return currentVariant == null ? null : (item: item, variant: currentVariant);
}

class _PickerDialog extends StatelessWidget {
  const _PickerDialog({required this.assets});

  final bool assets;

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final items = inventoryProvider.items
        .where((i) => i.active && (assets || i.tracking != Tracking.asset))
        .toList();
    return Dialog(
      child: SizedBox(
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) =>
                    inventoryProvider.loadItems(search: value),
                decoration: const InputDecoration(
                  hintText: 'Search items (whole word)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: inventoryProvider.itemsLoading
                          ? const CircularProgressIndicator()
                          : const Text('No items'),
                    )
                  : ListView(
                      children: [
                        for (final i in items)
                          ListTile(
                            title: Text(i.name),
                            subtitle: Text('${i.code} · ${i.stockUnit}'),
                            onTap: () => Navigator.pop(context, i),
                          ),
                        if (inventoryProvider.hasMoreItems)
                          TextButton(
                            onPressed: () =>
                                inventoryProvider.loadItems(more: true),
                            child: const Text('Load more'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
