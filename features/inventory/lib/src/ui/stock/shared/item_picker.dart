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
    builder: (_) => _VariantDialog(item: item, variants: variants),
  );
  return currentVariant == null ? null : (item: item, variant: currentVariant);
}

class _VariantDialog extends StatelessWidget {
  const _VariantDialog({required this.item, required this.variants});

  final InventoryItem item;
  final List<InventoryVariant> variants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerHeader(
              title: 'Choose a variant',
              subtitle: item.name,
              onClose: () => Navigator.pop(context),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: variants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  final attrs = variant.attrs.values.join(' · ');
                  return _PickerTile(
                    title: attrs.isEmpty ? variant.sku : attrs,
                    subtitle: attrs.isEmpty ? null : variant.sku,
                    onTap: () => Navigator.pop(context, variant),
                  );
                },
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _PickerDialog extends StatefulWidget {
  const _PickerDialog({required this.assets});

  final bool assets;

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
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
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerHeader(
              title: 'Select an item',
              subtitle: loading ? 'Loading…' : '${items.length} available',
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ListenableBuilder(
                listenable: _search,
                builder: (context, _) => TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(inventoryProvider),
                  decoration: InputDecoration(
                    hintText: 'Search by item name',
                    helperText: 'Press enter to search',
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
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
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
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount:
                          items.length +
                          (inventoryProvider.hasMoreItems ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return IcueButton(
                            label: 'Load more',
                            onPressed: () =>
                                inventoryProvider.loadItems(more: true),
                            variant: IcueButtonVariant.ghost,
                          );
                        }
                        final item = items[index];
                        final category = inventoryProvider
                            .category(item.categoryId)
                            ?.name;
                        return _PickerTile(
                          title: item.name,
                          subtitle: category,
                          trailing: [
                            if (item.stockUnit.isNotEmpty) item.stockUnit,
                            if (item.tracking == Tracking.batch) 'Batch',
                          ].join(' · '),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
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
