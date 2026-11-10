import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/unavailable/widgets/unavailable_table.dart';
import 'package:provider/provider.dart';

/// Open damaged / expired stock (FRS 10.12) and how it is resolved.
class UnavailablePage extends StatefulWidget {
  const UnavailablePage({super.key});

  @override
  State<UnavailablePage> createState() => _UnavailablePageState();
}

class _UnavailablePageState extends State<UnavailablePage> {
  String _selectedStatus = 'open';

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final stockProvider = context.read<StockProvider>();
    await stockProvider.loadAllStores();
    if (mounted) {
      await stockProvider.loadUnavailable(inventoryProvider.access);
    }
  }

  Future<void> _resolve(InventoryUnavailable item) async {
    await context.push(
      '${InventoryRoutes.inventoryUnavailableResolve}?id=${item.id}',
    );
    if (mounted) await _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.watch<StockProvider>();
    final operate = context.watch<InventoryProvider>().access.can(
      'inventory.stock.operate',
    );

    String storeName(String id) =>
        stockProvider.allStores
            .where((currentStore) => currentStore.id == id)
            .firstOrNull
            ?.name ??
        id;

    final allItems = stockProvider.unavailable;
    final filteredItems = allItems.where((item) {
      if (_selectedStatus == 'all') return true;
      return item.status == _selectedStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Damaged / Expired Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: context.isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: UnavailableTable(
                records: allItems,
                loading: stockProvider.isLoading,
                errorMessage: stockProvider.errorMessage,
                itemName: stockProvider.itemName,
                storeName: storeName,
                canOperate: operate,
                onResolve: _resolve,
                onRetry: _load,
              ),
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'open',
                          'Open (${allItems.where((i) => i.status == "open").length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'in_repair',
                          'In Repair (${allItems.where((i) => i.status == "in_repair").length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'resolved',
                          'Resolved (${allItems.where((i) => i.status == "resolved").length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip('all', 'All (${allItems.length})'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: stockProvider.isLoading && allItems.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 56,
                                      color: theme.colorScheme.outline,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _selectedStatus == 'open'
                                          ? 'No open damaged or expired items'
                                          : 'No items in this category',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quarantined or damaged stock recorded during receipt, returns or audits appears here.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final canResolve =
                                    operate && item.status != 'resolved';
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: item.status == 'open'
                                          ? theme.colorScheme.error.withValues(
                                              alpha: 0.3,
                                            )
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: canResolve
                                        ? () => _resolve(item)
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      stockProvider.itemName(
                                                        item.itemId,
                                                      ),
                                                      style: theme
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Store: ${storeName(item.storeId)}${item.batchNumber == null ? '' : ' · Batch ${item.batchNumber}'}',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .errorContainer
                                                      .withValues(alpha: 0.35),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${item.quantity.toQuantityText()} units',
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _buildBucketBadge(
                                                item.bucket ?? item.reason,
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusBadge(
                                                item.status,
                                                item.resolution,
                                              ),
                                              const Spacer(),
                                              if (item.createdAt != null)
                                                Text(
                                                  item.createdAt!
                                                      .toNumericDate(),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          if (item.remarks != null &&
                                              item.remarks!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.35),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .chat_bubble_outline_rounded,
                                                    size: 14,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      item.remarks!,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (canResolve) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Tap to resolve',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 12,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = key),
    );
  }

  Widget _buildBucketBadge(String bucket) {
    final isDamaged = bucket.toLowerCase().contains('damage');
    final isExpired = bucket.toLowerCase().contains('expire');
    final color = isDamaged
        ? Colors.red[800]!
        : isExpired
        ? Colors.amber[900]!
        : Colors.blueGrey[800]!;
    final backgroundColor = isDamaged
        ? Colors.red.withValues(alpha: 0.12)
        : isExpired
        ? Colors.amber.withValues(alpha: 0.12)
        : Colors.blueGrey.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        humanizeStatus(bucket),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String? resolution) {
    final text = resolution != null
        ? '${humanizeStatus(status)}: ${humanizeStatus(resolution)}'
        : humanizeStatus(status);
    final isResolved = status == 'resolved';
    final isInRepair = status == 'in_repair';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isResolved
            ? Colors.green.withValues(alpha: 0.12)
            : isInRepair
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isResolved
              ? Colors.green[800]
              : isInRepair
              ? Colors.blue[800]
              : Colors.orange[900],
        ),
      ),
    );
  }
}
