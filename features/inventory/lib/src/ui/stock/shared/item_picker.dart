import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
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
  final item = await IcueDialog.show<InventoryItem>(
    context,
    title: 'Select an item',
    size: IcueDialogSize.large,
    content: _ItemList(assets: assets),
    primaryAction: _cancelAction(context),
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
  final currentVariant = await IcueDialog.show<InventoryVariant>(
    context,
    title: 'Choose a variant',
    description: item.name,
    content: _VariantList(variants: variants),
    primaryAction: _cancelAction(context),
  );
  return currentVariant == null ? null : (item: item, variant: currentVariant);
}

IcueDialogAction _cancelAction(BuildContext context) => IcueDialogAction(
  label: 'Cancel',
  variant: IcueButtonVariant.ghost,
  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
);

class _VariantList extends StatelessWidget {
  const _VariantList({required this.variants});

  final List<InventoryVariant> variants;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: variants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final variant = variants[index];
        final attrs = variant.attrs.values.join(' · ');
        return _PickerTile(
          title: attrs.isEmpty ? variant.sku : attrs,
          subtitle: attrs.isEmpty ? null : variant.sku,
          onTap: () => Navigator.of(context, rootNavigator: true).pop(variant),
        );
      },
    );
  }
}

class _ItemList extends StatefulWidget {
  const _ItemList({required this.assets});

  final bool assets;

  @override
  State<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<_ItemList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _run(InventoryProvider provider) =>
      provider.loadItems(search: _search.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final items = inventoryProvider.items
        .where(
          (item) =>
              item.active && (widget.assets || item.tracking != Tracking.asset),
        )
        .toList();
    final loading = inventoryProvider.itemsLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: _search,
          builder: (context, _) => TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(inventoryProvider),
            decoration: InputDecoration(
              hintText: 'Search by item name',
              helperText: loading
                  ? 'Loading…'
                  : '${items.length} available · press enter to search',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        _run(inventoryProvider);
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No items found',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'Try a different name.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length + (inventoryProvider.hasMoreItems ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return IcueButton(
                  label: 'Load more',
                  onPressed: () => inventoryProvider.loadItems(more: true),
                  variant: IcueButtonVariant.ghost,
                );
              }
              final item = items[index];
              return _PickerTile(
                title: item.name,
                subtitle: inventoryProvider.category(item.categoryId)?.name,
                trailing: [
                  if (item.stockUnit.isNotEmpty) item.stockUnit,
                  if (item.tracking == Tracking.batch) 'Batch',
                ].join(' · '),
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(item),
              );
            },
          ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
