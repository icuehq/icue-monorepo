import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/stock/unavailable/widgets/unavailable_card.dart';
import 'package:inventory/src/ui/stock/unavailable/widgets/unavailable_table.dart';
import 'package:provider/provider.dart';

/// Damaged / expired stock (FRS 10.12) and how it is resolved; status filter, item-name search and paging run on the server.
class UnavailablePage extends StatefulWidget {
  const UnavailablePage({super.key});

  @override
  State<UnavailablePage> createState() => _UnavailablePageState();
}

class _UnavailablePageState extends State<UnavailablePage> {
  static const _statuses = {
    'open': 'Open',
    'in_repair': 'In repair',
    'resolved': 'Resolved',
  };

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final stockProvider = context.read<StockProvider>();
    await stockProvider.loadAllStores();
    if (mounted) await stockProvider.unavailableRecords.load();
  }

  Future<void> _resolve(InventoryUnavailable record) async {
    await context.push(
      '${InventoryRoutes.inventoryUnavailableResolve}?id=${record.id}',
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
    final stockProvider = context.watch<StockProvider>();
    const operate = true;

    String storeName(String id) =>
        stockProvider.allStores
            .where((currentStore) => currentStore.id == id)
            .firstOrNull
            ?.name ??
        id;

    return PagedListPage<InventoryUnavailable>(
      title: 'Damaged / Expired Stock',
      state: stockProvider.unavailableRecords,
      statuses: _statuses,
      searchHint: 'Search by item name…',
      emptyIcon: Icons.verified_outlined,
      emptyMessage: 'Quarantined or damaged stock recorded during receipt, returns or audits appears here.',
      onRefresh: _load,
      itemCard: (context, record) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: UnavailableCard(
          item: record,
          itemName: stockProvider.itemName,
          storeName: storeName,
          canOperate: operate,
          onResolve: _resolve,
        ),
      ),
      table: UnavailableTable(
        state: stockProvider.unavailableRecords,
        statuses: _statuses,
        itemName: stockProvider.itemName,
        storeName: storeName,
        canOperate: operate,
        onResolve: _resolve,
      ),
    );
  }
}
