import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

typedef PickedItem = ({InvItem item, InvVariant? variant});

/// Search-and-pick dialog for stock lines. Asset-tracked items are managed in Assets, so they are hidden
/// unless [assets] (purchase requests can ask for them).
Future<PickedItem?> pickItem(
  BuildContext context, {
  bool assets = false,
}) async {
  final p = context.read<InventoryProvider>();
  await p.loadItems(search: '', clearCategory: true);
  if (!context.mounted) return null;
  final item = await showDialog<InvItem>(
    context: context,
    builder: (_) => _PickerDialog(assets: assets),
  );
  if (item == null || item.variantAttrs.isEmpty || !context.mounted) {
    return item == null ? null : (item: item, variant: null);
  }
  final variants = (await p.variants(item.id)).where((v) => v.active).toList();
  if (!context.mounted) return null;
  final v = await showDialog<InvVariant>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('${item.name} – variant'),
      children: [
        if (variants.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No active variants. Add one on the item page.'),
          ),
        for (final v in variants)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, v),
            child: Text('${v.sku} · ${v.attrs.values.join(' / ')}'),
          ),
      ],
    ),
  );
  return v == null ? null : (item: item, variant: v);
}

class _PickerDialog extends StatelessWidget {
  const _PickerDialog({required this.assets});

  final bool assets;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final items = p.items
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
                onSubmitted: (v) => p.loadItems(search: v),
                decoration: const InputDecoration(
                  hintText: 'Search items (whole word)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: p.itemsLoading
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
                        if (p.hasMoreItems)
                          TextButton(
                            onPressed: () => p.loadItems(more: true),
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
