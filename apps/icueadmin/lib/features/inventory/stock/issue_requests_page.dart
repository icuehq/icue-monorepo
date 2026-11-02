import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/issue_request_card.dart';
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
    final inventoryProvider = context.watch<InventoryProvider>();
    final access = inventoryProvider.access;
    final canRequest = access.can('inventory.issue.request');
    final theme = Theme.of(context);

    String storeName(String storeId) =>
        inventoryProvider.stores
            .where((store) => store.id == storeId)
            .firstOrNull
            ?.name ??
        storeId;

    final statuses = <(String?, String)>[
      (null, 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('partially_issued', 'Partially issued'),
      ('issued', 'Issued'),
      ('rejected', 'Rejected'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Requests')),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.inventoryRequestForm);
                if (mounted) await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New request'),
            )
          : null,
      body: Column(
        children: [
          // Horizontal Status Filter Chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final (key, label) in statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label),
                      selected: _status == key,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() => _status = key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  stockProvider.isLoading && stockProvider.requests.isEmpty
                      ? 'Loading requests…'
                      : '${stockProvider.requests.length} request${stockProvider.requests.length == 1 ? '' : 's'}'
                            '${_status != null ? ' in ${_status!.replaceAll('_', ' ')}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: stockProvider.requests.isEmpty
                  ? Center(
                      child: stockProvider.isLoading
                          ? const CircularProgressIndicator()
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.outbox_rounded,
                                        size: 36,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _status != null
                                          ? 'No $_status requests'
                                          : 'No issue requests',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _status != null
                                          ? 'There are currently no requests with this status filter.'
                                          : 'Submit an issue request to withdraw supplies or equipment from store stock.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (_status != null)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() => _status = null);
                                          _load();
                                        },
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Show all requests'),
                                      )
                                    else if (canRequest)
                                      FilledButton.icon(
                                        onPressed: () async {
                                          await context.push(
                                            AppRoutes.inventoryRequestForm,
                                          );
                                          if (mounted) await _load();
                                        },
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('New request'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: stockProvider.requests.length,
                      itemBuilder: (context, index) {
                        final issueRequest = stockProvider.requests[index];
                        return IssueRequestCard(
                          request: issueRequest,
                          storeName: storeName(issueRequest.storeId),
                          itemName: stockProvider.itemName,
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => RequestSheet(request: issueRequest),
                            );
                            if (mounted) await _load();
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
