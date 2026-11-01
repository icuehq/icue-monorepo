import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_request_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Purchase requests (FRS 10.13): own requests, or the campus's for approvers and procurement.
class PurchaseRequestsPage extends StatefulWidget {
  const PurchaseRequestsPage({super.key});

  @override
  State<PurchaseRequestsPage> createState() => _PurchaseRequestsPageState();
}

class _PurchaseRequestsPageState extends State<PurchaseRequestsPage> {
  static const _statuses = [
    'draft',
    'pending',
    'approved',
    'rejected',
    'revision_requested',
    'cancelled',
  ];
  String? _status;

  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.categories.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<ProcurementProvider>().loadRequests(
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
    final a = context.watch<InventoryProvider>().access;
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase requests')),
      floatingActionButton: a.can('inv.pr.request')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.inventoryPurchaseRequestForm);
                if (mounted) await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Request'),
            )
          : null,
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
            child: p.requests.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No purchase requests'),
                  )
                : ListView(
                    children: [
                      for (final r in p.requests)
                        ListTile(
                          title: Text('${r.number} · ${r.purpose}'),
                          subtitle: Text(
                            r.lines
                                .map(
                                  (l) =>
                                      '${p.itemName(l.itemId)} × ${fmtQty(l.qty)}',
                                )
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(statusLabel(r.status)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showInvSheet(
                              context,
                              () => PurchaseRequestSheet(request: r),
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
