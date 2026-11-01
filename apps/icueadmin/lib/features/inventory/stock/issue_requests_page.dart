import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/request_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Issue requests (FRS 10.8): list for requester / approver / storekeeper.
class IssueRequestsPage extends StatefulWidget {
  const IssueRequestsPage({super.key});

  @override
  State<IssueRequestsPage> createState() => _IssueRequestsPageState();
}

class _IssueRequestsPageState extends State<IssueRequestsPage> {
  String? _status;

  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.stores.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<StockProvider>().loadRequests(
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
    final p = context.watch<StockProvider>();
    final a = context.watch<InventoryProvider>().access;
    return Scaffold(
      appBar: AppBar(title: const Text('Issue requests')),
      floatingActionButton: a.can('inv.issue.request')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.inventoryRequestForm);
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
                for (final s in [
                  'pending',
                  'approved',
                  'partially_issued',
                  'issued',
                  'rejected',
                ])
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
                        : Text(p.errorMessage ?? 'No requests'),
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
                                      '${p.itemName(l.itemId)} × ${fmtQty(l.requested)}',
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
                              () => RequestSheet(request: r),
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
