import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_card.dart';
import 'package:provider/provider.dart';

/// Issue requests (FRS 10.8): list for requester / approver / storekeeper.
class IssueRequestsPage extends StatefulWidget {
  const IssueRequestsPage({super.key});

  @override
  State<IssueRequestsPage> createState() => _IssueRequestsPageState();
}

class _IssueRequestsPageState extends State<IssueRequestsPage> {
  String? _status;

  /// False until the first fetch ends, so stale rows from an earlier visit never flash.
  var _loaded = false;

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (mounted) {
      await context.read<StockProvider>().loadRequests(
        inventoryProvider.access,
        status: _status,
      );
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _filter(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _load();
  }

  Future<void> _newRequest() async {
    await context.push(InventoryRoutes.inventoryRequestForm);
    if (mounted) await _load();
  }

  Future<void> _open(InventoryIssueRequest request) async {
    await context.push(
      '${InventoryRoutes.inventoryRequestDetail}?id=${request.id}',
    );
    if (mounted) await _load();
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
      ('cancelled', 'Cancelled'),
      ('closed', 'Closed'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Requests')),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: _newRequest,
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
                      onSelected: (_) => _filter(key),
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
                  !_loaded || stockProvider.isLoading
                      ? 'Loading requests…'
                      : '${stockProvider.requests.length} '
                            '${_status == null ? '' : '${humanizeStatus(_status!).toLowerCase()} '}'
                            'request${stockProvider.requests.length == 1 ? '' : 's'}',
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
              child: !_loaded || stockProvider.requests.isEmpty
                  ? Center(
                      child: !_loaded || stockProvider.isLoading
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
                                      stockProvider.errorMessage != null
                                          ? 'Could not load requests'
                                          : _status != null
                                          ? 'No ${humanizeStatus(_status!).toLowerCase()} requests'
                                          : 'No issue requests',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      stockProvider.errorMessage ??
                                          (_status != null
                                              ? 'There are currently no requests with this status filter.'
                                              : 'Submit an issue request to withdraw supplies or equipment from store stock.'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (stockProvider.errorMessage != null)
                                      OutlinedButton.icon(
                                        onPressed: _load,
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                        ),
                                        label: const Text('Try again'),
                                      )
                                    else if (_status != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _filter(null),
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Show all requests'),
                                      )
                                    else if (canRequest)
                                      FilledButton.icon(
                                        onPressed: _newRequest,
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
                          onTap: () => _open(issueRequest),
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
