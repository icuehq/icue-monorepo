import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_card.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_sheet.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Purchase orders (FRS 10.16) on the caller's campuses. Created from a request's quotations or the request sheet.
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      final procurementProvider = context.read<ProcurementProvider>();
      if (procurementProvider.vendors.isEmpty) {
        await procurementProvider.loadVendors();
      }
      if (mounted) {
        await procurementProvider.loadOrders(
          inventoryProvider.access,
          status: _selectedStatus == 'all' ? null : _selectedStatus,
        );
      }
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

    final allOrders = procurementProvider.orders;
    final query = _searchController.text.trim().toLowerCase();

    final filteredOrders = allOrders.where((order) {
      if (_selectedStatus != 'all' && order.status != _selectedStatus) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesNumber = order.number.toLowerCase().contains(query);
        final vendorName = procurementProvider
            .vendorName(order.vendorId)
            .toLowerCase();
        final matchesVendor = vendorName.contains(query);
        if (!matchesNumber && !matchesVendor) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by PO number or vendor name…',
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
                _buildFilterChip('all', 'All (${allOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'issued',
                  'Issued (${allOrders.where((o) => o.status == "issued").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'acknowledged',
                  'Acknowledged (${allOrders.where((o) => o.status == "acknowledged").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'partially_received',
                  'In Delivery (${allOrders.where((o) => o.status == "partially_received").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'fully_received',
                  'Received (${allOrders.where((o) => o.status == "fully_received").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'draft',
                  'Draft (${allOrders.where((o) => o.status == "draft").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'closed',
                  'Closed (${allOrders.where((o) => o.status == "closed").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'cancelled',
                  'Cancelled (${allOrders.where((o) => o.status == "cancelled").length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: procurementProvider.isLoading && allOrders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              query.isNotEmpty
                                  ? 'No orders matching "$query"'
                                  : _selectedStatus == 'all'
                                  ? 'No purchase orders found'
                                  : 'No $_selectedStatus purchase orders',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Purchase orders are created from approved purchase requests and quotations.',
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
                      itemCount: filteredOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final purchaseOrder = filteredOrders[index];
                        return PurchaseOrderCard(
                          order: purchaseOrder,
                          vendorName: procurementProvider.vendorName(
                            purchaseOrder.vendorId,
                          ),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => PurchaseOrderSheet(order: purchaseOrder),
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
