import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_sheet.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Purchase orders (FRS 10.16) on the caller's campuses. Created from a request's quotations or the request sheet.
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  static const _statuses = [
    'draft',
    'issued',
    'acknowledged',
    'partially_received',
    'fully_received',
    'closed',
    'cancelled',
  ];
  String? _status;

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      await context.read<ProcurementProvider>().loadOrders(
        inventoryProvider.access,
        status: _status,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _status,
              items: [
                const DropdownMenuItem(child: Text('All statuses')),
                for (final status in _statuses)
                  DropdownMenuItem(
                    value: status,
                    child: Text(humanizeStatus(status)),
                  ),
              ],
              onChanged: (value) {
                _status = value;
                _load();
              },
            ),
          ),
          Expanded(
            child: procurementProvider.orders.isEmpty
                ? Center(
                    child: procurementProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            procurementProvider.errorMessage ??
                                'No purchase orders',
                          ),
                  )
                : ListView(
                    children: [
                      for (final purchaseOrder in procurementProvider.orders)
                        ListTile(
                          title: Text(
                            '${purchaseOrder.number} · ${procurementProvider.vendorName(purchaseOrder.vendorId)}',
                          ),
                          subtitle: Text(
                            'Total ${money(purchaseOrder.total)} · due ${purchaseOrder.expectedDate}'
                            '${purchaseOrder.revision > 0 ? ' · rev ${purchaseOrder.revision}' : ''}',
                          ),
                          trailing: Chip(
                            label: Text(humanizeStatus(purchaseOrder.status)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => PurchaseOrderSheet(order: purchaseOrder),
                            );
                            if (mounted) await _load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
