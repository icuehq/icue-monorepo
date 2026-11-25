import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Stock list notice: asset units received into the store but not registered yet, with a way to register them.
/// Reloads when [storeId] changes or the widget is rebuilt with a new key.
class UnregisteredAssetsCard extends StatefulWidget {
  const UnregisteredAssetsCard({this.storeId, super.key});

  final String? storeId;

  @override
  State<UnregisteredAssetsCard> createState() => _UnregisteredAssetsCardState();
}

class _UnregisteredAssetsCardState extends State<UnregisteredAssetsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          context.read<AssetsProvider>().loadUnregisteredStock(widget.storeId),
    );
  }

  @override
  void didUpdateWidget(UnregisteredAssetsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) {
      context.read<AssetsProvider>().loadUnregisteredStock(widget.storeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final rows = assetsProvider.unregisteredStock;
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final total = rows.fold<int>(0, (sum, row) => sum + row.count);
    String storeName(String id) =>
        inventoryProvider.stores
            .where((store) => store.id == id)
            .firstOrNull
            ?.name ??
        id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.shade700.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$total unregistered asset${total == 1 ? '' : 's'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push(InventoryRoutes.inventoryAssets),
                  child: const Text('Register'),
                ),
              ],
            ),
            for (final row in rows.take(4))
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text(
                  '${assetsProvider.itemName(row.itemId)} × ${row.count}'
                  '${widget.storeId == null ? ' · ${storeName(row.storeId)}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (rows.length > 4)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text(
                  'and ${rows.length - 4} more',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
