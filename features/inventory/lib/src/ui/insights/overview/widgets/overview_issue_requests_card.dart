import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_card.dart';
import 'package:provider/provider.dart';

/// The newest pending issue requests, shown right after the KPIs as the dashboard's priority list.
class OverviewIssueRequestsCard extends StatefulWidget {
  const OverviewIssueRequestsCard({super.key});

  @override
  State<OverviewIssueRequestsCard> createState() =>
      _OverviewIssueRequestsCardState();
}

class _OverviewIssueRequestsCardState extends State<OverviewIssueRequestsCard> {
  late Future<List<InventoryIssueRequest>> _requests;

  void _load() => _requests = context.read<StockProvider>().pendingRequests();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _open(InventoryIssueRequest request) async {
    await context.push(
      '${InventoryRoutes.inventoryRequestDetail}?id=${request.id}',
    );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.read<StockProvider>();
    final storeNames = {
      for (final store in context.watch<InventoryProvider>().stores)
        store.id: store.name,
    };
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pending issue requests',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(InventoryRoutes.inventoryRequests),
                child: const Text('View all'),
              ),
            ],
          ),
          FutureBuilder<List<InventoryIssueRequest>>(
            future: _requests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(callableErrorMessage(snapshot.error!));
              }
              final requests = snapshot.data;
              if (requests == null) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No pending issue requests',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final request in requests)
                    IssueRequestCard(
                      request: request,
                      storeName: storeNames[request.storeId] ?? request.storeId,
                      itemName: stockProvider.itemName,
                      onTap: () => _open(request),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
