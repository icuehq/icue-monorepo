import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/widgets/purchase_order_card.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:provider/provider.dart';

/// Purchase orders (FRS 10.16) of the branch. Created from a request's quotations or the request sheet.
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  static const _statuses = {
    'draft': 'Draft',
    'issued': 'Issued',
    'acknowledged': 'Acknowledged',
    'partially_received': 'In delivery',
    'fully_received': 'Received',
    'closed': 'Closed',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (!mounted) return;
    final provider = context.read<ProcurementProvider>();
    await provider.ensureVendors();
    await provider.purchaseOrders.load();
  }

  Future<void> _open(InventoryPurchaseOrder order) async {
    await context.push(
      InventoryRoutes.inventoryPurchaseOrderDetail,
      extra: order,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProcurementProvider>();
    return PagedListPage<InventoryPurchaseOrder>(
      title: 'Purchase Orders',
      state: provider.purchaseOrders,
      statuses: _statuses,
      searchHint: 'Search by PO number…',
      emptyIcon: Icons.receipt_long_outlined,
      emptyMessage: 'Purchase orders are created from approved purchase requests and quotations.',
      onRefresh: _load,
      itemCard: (context, order) => PurchaseOrderCard(
        order: order,
        vendorName: provider.vendorName(order.vendorId),
        onTap: () => _open(order),
      ),
      table: PagedListTable<InventoryPurchaseOrder>(
        title: 'Purchase orders',
        state: provider.purchaseOrders,
        statuses: _statuses,
        searchHint: 'PO number, e.g. PO/2025-26',
        rowKey: (order) => order.id,
        rowLabel: (order) => order.number,
        onOpen: _open,
        emptyMessage: 'Purchase orders are created from approved purchase requests and quotations.',
        columns: [
          IcueTableColumn(
            id: 'number',
            label: 'Order',
            cellBuilder: (context, order) => IcueTableCellText(
              order.number.isEmpty ? 'Draft' : order.number,
            ),
          ),
          IcueTableColumn(
            id: 'vendor',
            label: 'Vendor',
            flex: 2,
            cellBuilder: (context, order) =>
                IcueTableCellText(provider.vendorName(order.vendorId)),
          ),
          IcueTableColumn(
            id: 'status',
            label: 'Status',
            cellBuilder: (context, order) =>
                IcueTableCellText(humanizeStatus(order.status)),
          ),
          IcueTableColumn(
            id: 'due',
            label: 'Due',
            hideBelowWidth: 900,
            cellBuilder: (context, order) =>
                IcueTableCellText(order.expectedDate.toDisplayDay()),
          ),
          IcueTableColumn(
            id: 'total',
            label: 'Total',
            cellBuilder: (context, order) =>
                IcueTableCellText(order.total.toRupees()),
          ),
        ],
      ),
    );
  }
}
