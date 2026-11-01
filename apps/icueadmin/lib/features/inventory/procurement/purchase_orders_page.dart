import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
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
    final inv = context.read<InventoryProvider>();
    if (inv.categories.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<ProcurementProvider>().loadOrders(
        inv.access,
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
    final p = context.watch<ProcurementProvider>();
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
                for (final s in _statuses)
                  DropdownMenuItem(value: s, child: Text(statusLabel(s))),
              ],
              onChanged: (v) {
                _status = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: p.orders.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No purchase orders'),
                  )
                : ListView(
                    children: [
                      for (final o in p.orders)
                        ListTile(
                          title: Text(
                            '${o.number} · ${p.vendorName(o.vendorId)}',
                          ),
                          subtitle: Text(
                            'Total ${money(o.total)} · due ${o.expectedDate}'
                            '${o.revision > 0 ? ' · rev ${o.revision}' : ''}',
                          ),
                          trailing: Chip(
                            label: Text(statusLabel(o.status)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showInvSheet(
                              context,
                              () => PurchaseOrderSheet(order: o),
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
