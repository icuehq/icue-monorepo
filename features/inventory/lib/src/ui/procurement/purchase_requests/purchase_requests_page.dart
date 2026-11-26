import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_card.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:provider/provider.dart';

/// Purchase requests of the stores the user works in (a store manager's own, or every store for admins).
class PurchaseRequestsPage extends StatefulWidget {
  const PurchaseRequestsPage({super.key});

  @override
  State<PurchaseRequestsPage> createState() => _PurchaseRequestsPageState();
}

class _PurchaseRequestsPageState extends State<PurchaseRequestsPage> {
  static const _statuses = {
    'open': 'Open',
    'partially_received': 'Partially received',
    'received': 'Received',
    'closed': 'Closed',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    await context.read<ProcurementProvider>().purchaseRequests.load();
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  void _openRequest(InventoryPurchaseRequest request) => _open(
    '${InventoryRoutes.inventoryPurchaseRequestDetail}?id=${request.id}',
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    String? storeName(String id) => inventoryProvider.stores
        .where((store) => store.id == id)
        .firstOrNull
        ?.name;
    final manyStores = inventoryProvider.stores.length > 1;
    final newRequest = IcueTableAction(
      label: 'New request',
      icon: Icons.add_rounded,
      onPressed: () => _open(InventoryRoutes.inventoryPurchaseRequestForm),
    );
    return PagedListPage<InventoryPurchaseRequest>(
      title: 'Purchase Requests',
      state: provider.purchaseRequests,
      statuses: _statuses,
      searchHint: 'Search by request number…',
      emptyIcon: Icons.request_quote_outlined,
      emptyMessage: 'Raise a request for what a store needs to buy.',
      onRefresh: _load,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(InventoryRoutes.inventoryPurchaseRequestForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      itemCard: (context, request) => PurchaseRequestCard(
        request: request,
        getItemName: provider.itemName,
        storeName: manyStores ? storeName(request.storeId) : null,
        onTap: () => _openRequest(request),
      ),
      table: PagedListTable<InventoryPurchaseRequest>(
        title: 'Purchase requests',
        state: provider.purchaseRequests,
        statuses: _statuses,
        searchHint: 'Request number, e.g. PR/2025-26',
        rowKey: (request) => request.id,
        rowLabel: (request) => request.number,
        onOpen: _openRequest,
        primaryAction: newRequest,
        emptyMessage: 'Raise a request for what a store needs to buy.',
        columns: [
          IcueTableColumn(
            id: 'number',
            label: 'Request',
            cellBuilder: (context, request) =>
                IcueTableCellText(request.number),
          ),
          if (manyStores)
            IcueTableColumn(
              id: 'store',
              label: 'Store',
              hideBelowWidth: 900,
              cellBuilder: (context, request) =>
                  IcueTableCellText(storeName(request.storeId) ?? ''),
            ),
          IcueTableColumn(
            id: 'purpose',
            label: 'Purpose',
            flex: 3,
            cellBuilder: (context, request) =>
                IcueTableCellText(request.purpose),
          ),
          IcueTableColumn(
            id: 'priority',
            label: 'Priority',
            hideBelowWidth: 900,
            cellBuilder: (context, request) =>
                IcueTableCellText(humanizeStatus(request.priority)),
          ),
          IcueTableColumn(
            id: 'needed',
            label: 'Needed by',
            hideBelowWidth: 900,
            cellBuilder: (context, request) =>
                IcueTableCellText(request.requiredDate.toDisplayDay()),
          ),
          IcueTableColumn(
            id: 'status',
            label: 'Status',
            cellBuilder: (context, request) =>
                IcueTableCellText(inventoryStatusLabel(request.status)),
          ),
        ],
      ),
    );
  }
}
