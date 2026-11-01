import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/request_sheet.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (mounted) {
      await context.read<StockProvider>().loadRequests(
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
    final stockProvider = context.watch<StockProvider>();
    final access = context.watch<InventoryProvider>().access;
    return Scaffold(
      appBar: AppBar(title: const Text('Issue requests')),
      floatingActionButton: access.can('inventory.issue.request')
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
                for (final value in [
                  'pending',
                  'approved',
                  'partially_issued',
                  'issued',
                  'rejected',
                ])
                  DropdownMenuItem(
                    value: value,
                    child: Text(humanizeStatus(value)),
                  ),
              ],
              onChanged: (value) {
                _status = value;
                _load();
              },
            ),
          ),
          Expanded(
            child: stockProvider.requests.isEmpty
                ? Center(
                    child: stockProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(stockProvider.errorMessage ?? 'No requests'),
                  )
                : ListView(
                    children: [
                      for (final issueRequest in stockProvider.requests)
                        ListTile(
                          title: Text(
                            '${issueRequest.number} · ${issueRequest.purpose}',
                          ),
                          subtitle: Text(
                            issueRequest.lineItems
                                .map(
                                  (requestLine) =>
                                      '${stockProvider.itemName(requestLine.itemId)} × ${formatQuantity(requestLine.requested)}',
                                )
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(humanizeStatus(issueRequest.status)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => RequestSheet(request: issueRequest),
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
