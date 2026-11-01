import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_request_sheet.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      await context.read<ProcurementProvider>().loadRequests(
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
    final access = context.watch<InventoryProvider>().access;
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase requests')),
      floatingActionButton: access.can('inventory.purchaseRequest.request')
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
            child: procurementProvider.requests.isEmpty
                ? Center(
                    child: procurementProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            procurementProvider.errorMessage ??
                                'No purchase requests',
                          ),
                  )
                : ListView(
                    children: [
                      for (final purchaseRequest
                          in procurementProvider.requests)
                        ListTile(
                          title: Text(
                            '${purchaseRequest.number} · ${purchaseRequest.purpose}',
                          ),
                          subtitle: Text(
                            purchaseRequest.lineItems
                                .map(
                                  (purchaseRequestLine) =>
                                      '${procurementProvider.itemName(purchaseRequestLine.itemId)} × ${formatQuantity(purchaseRequestLine.quantity)}',
                                )
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(humanizeStatus(purchaseRequest.status)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => PurchaseRequestSheet(
                                request: purchaseRequest,
                              ),
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
