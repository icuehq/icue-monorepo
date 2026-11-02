import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_request_card.dart';
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
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      await context.read<ProcurementProvider>().loadRequests(
        inventoryProvider.access,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final access = context.watch<InventoryProvider>().access;
    final canRequest = access.can('inventory.purchaseRequest.request');

    final allRequests = procurementProvider.requests;
    final query = _searchController.text.trim().toLowerCase();

    final filteredRequests = allRequests.where((req) {
      if (_selectedStatus != 'all' && req.status != _selectedStatus) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesNumber = req.number.toLowerCase().contains(query);
        final matchesPurpose = req.purpose.toLowerCase().contains(query);
        if (!matchesNumber && !matchesPurpose) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.inventoryPurchaseRequestForm);
                if (mounted) await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            )
          : null,
      body: Column(
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
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
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
                const SizedBox(width: 8),
                _buildFilterChip(
                  'pending',
                  'Pending (${allRequests.where((r) => r.isPending).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'approved',
                  'Approved (${allRequests.where((r) => r.status == "approved" || r.status == "partially_ordered").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'draft',
                  'Draft (${allRequests.where((r) => r.status == "draft").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'revision_requested',
                  'Returned (${allRequests.where((r) => r.status == "revision_requested").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'rejected',
                  'Rejected (${allRequests.where((r) => r.status == "rejected").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'cancelled',
                  'Cancelled (${allRequests.where((r) => r.status == "cancelled").length})',
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
              child: procurementProvider.isLoading && allRequests.isEmpty
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
                              query.isNotEmpty
                                  ? 'No requests matching "$query"'
                                  : _selectedStatus == 'all'
                                  ? 'No purchase requests found'
                                  : 'No $_selectedStatus requests',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              canRequest
                                  ? 'Raise a requisition to procure materials or assets for your campus.'
                                  : 'Purchase requests will appear here once submitted.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRequests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final purchaseRequest = filteredRequests[index];
                        return PurchaseRequestCard(
                          request: purchaseRequest,
                          getItemName: procurementProvider.itemName,
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => PurchaseRequestSheet(
                                request: purchaseRequest,
                              ),
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

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedStatus = key);
        _load();
      },
    );
  }
}
