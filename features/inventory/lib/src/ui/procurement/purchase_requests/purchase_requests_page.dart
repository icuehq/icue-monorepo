import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/purchase_request_rules.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_card.dart';
import 'package:provider/provider.dart';

/// Purchase requests (FRS 10.13): own requests, or the branch's for approvers and procurement.
class PurchaseRequestsPage extends StatefulWidget {
  const PurchaseRequestsPage({super.key});

  @override
  State<PurchaseRequestsPage> createState() => _PurchaseRequestsPageState();
}

class _PurchaseRequestsPageState extends State<PurchaseRequestsPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';

  /// False until the first fetch ends, so an earlier visit's rows never flash.
  var _loaded = false;

  /// Chips group statuses; counts and filtering both use these.
  static const _groups = <(String, String, List<String>)>[
    ('pending', 'Pending', ['pending']),
    ('approved', 'Approved', ['approved', 'partially_ordered']),
    ('ordered', 'Ordered', ['ordered']),
    ('draft', 'Draft', ['draft']),
    ('revision_requested', 'Returned', ['revision_requested']),
    ('rejected', 'Rejected', ['rejected']),
    ('cancelled', 'Cancelled', ['cancelled']),
  ];

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      // All statuses are fetched once; the chips filter (and count) them here.
      await context.read<ProcurementProvider>().loadRequests(
        inventoryProvider.access,
      );
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRequest(InventoryPurchaseRequest request) => _open(
    '${InventoryRoutes.inventoryPurchaseRequestDetail}?id=${request.id}',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final access = context.watch<InventoryProvider>().access;
    final canRequest = access.can('inventory.purchaseRequest.request');

    final allRequests = procurementProvider.requests;
    final query = _searchController.text.trim().toLowerCase();

    final selectedStatuses = _groups
        .where((group) => group.$1 == _selectedStatus)
        .firstOrNull
        ?.$3;
    final filteredRequests = [
      for (final request in allRequests)
        if ((selectedStatuses == null ||
                selectedStatuses.contains(request.status)) &&
            (query.isEmpty ||
                request.number.toLowerCase().contains(query) ||
                request.purpose.toLowerCase().contains(query)))
          request,
    ];
    final failure = procurementProvider.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Requests')),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _open(InventoryRoutes.inventoryPurchaseRequestForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            )
          : null,
      body: IcueCenteredBody(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by PR number or purpose…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Horizontal Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${allRequests.length})'),
                  for (final (key, label, statuses) in _groups)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildFilterChip(
                        key,
                        '$label (${allRequests.where((r) => statuses.contains(r.status)).length})',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Requests List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child:
                    !_loaded ||
                        (procurementProvider.isLoading && allRequests.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : filteredRequests.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 56,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                failure != null
                                    ? 'Could not load requests'
                                    : query.isNotEmpty
                                    ? 'No requests matching "$query"'
                                    : _selectedStatus == 'all'
                                    ? 'No purchase requests found'
                                    : 'No requests in this status',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                failure ??
                                    (canRequest
                                        ? 'Raise a requisition to procure materials or assets for your branch.'
                                        : 'Purchase requests will appear here once submitted.'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : IcueAdaptiveList<InventoryPurchaseRequest>(
                        items: filteredRequests,
                        onTap: _openRequest,
                        columns: [
                          IcueAdaptiveColumn.text(
                            'Request',
                            (request) => request.number.isEmpty
                                ? 'Draft'
                                : request.number,
                          ),
                          IcueAdaptiveColumn.text(
                            'Purpose',
                            (request) => request.purpose,
                            flex: 3,
                          ),
                          IcueAdaptiveColumn.text(
                            'Priority',
                            (request) => humanizeStatus(request.priority),
                          ),
                          IcueAdaptiveColumn.text(
                            'Needed by',
                            (request) => request.requiredDate.toDisplayDay(),
                          ),
                          IcueAdaptiveColumn.text(
                            'Estimate',
                            (request) => request.total.toRupees(),
                          ),
                          IcueAdaptiveColumn.text(
                            'Status',
                            (request) => humanizeStatus(request.status),
                          ),
                        ],
                        cardBuilder: (context, purchaseRequest) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: PurchaseRequestCard(
                            request: purchaseRequest,
                            getItemName: procurementProvider.itemName,
                            nextAction: purchaseNextAction(
                              purchaseRequest,
                              access,
                              procurementProvider.uid,
                            ),
                            onTap: () => _openRequest(purchaseRequest),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = key),
    );
  }
}
