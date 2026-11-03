import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/invoice_card.dart';
import 'package:inventory/src/ui/procurement/invoice_sheet.dart';
import 'package:provider/provider.dart';

/// Vendor invoice records (FRS 10.18). Recorded from a purchase order; lists and updates payment status.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

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
        await procurementProvider.loadInvoices(
          inventoryProvider.access,
          status: _selectedStatus == 'overdue' || _selectedStatus == 'all'
              ? null
              : _selectedStatus,
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

    final allInvoices = procurementProvider.invoices;
    final query = _searchController.text.trim().toLowerCase();

    final shown = allInvoices.where((i) {
      final derivedStatus = i.statusOn(_today);
      if (_selectedStatus != 'all') {
        if (_selectedStatus == 'overdue') {
          if (derivedStatus != 'overdue') return false;
        } else if (i.paymentStatus != _selectedStatus) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final matchesNumber = i.invoiceNumber.toLowerCase().contains(query);
        final matchesPo = i.purchaseOrderNumber.toLowerCase().contains(query);
        final vendorName = procurementProvider
            .vendorName(i.vendorId)
            .toLowerCase();
        final matchesVendor = vendorName.contains(query);
        if (!matchesNumber && !matchesPo && !matchesVendor) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Invoices'),
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
                hintText: 'Search by invoice no., PO no. or vendor…',
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
                _buildFilterChip('all', 'All (${allInvoices.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'unpaid',
                  'Unpaid (${allInvoices.where((i) => i.isUnpaid).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'partially_paid',
                  'Partially Paid (${allInvoices.where((i) => i.paymentStatus == "partially_paid").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'paid',
                  'Paid (${allInvoices.where((i) => i.paymentStatus == "paid").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'overdue',
                  'Overdue (${allInvoices.where((i) => i.statusOn(_today) == "overdue").length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'cancelled',
                  'Cancelled (${allInvoices.where((i) => i.isCancelled).length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Invoices List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: procurementProvider.isLoading && allInvoices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              query.isNotEmpty
                                  ? 'No invoices matching "$query"'
                                  : _selectedStatus == 'all'
                                  ? 'No vendor invoices recorded'
                                  : 'No $_selectedStatus invoices',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Record vendor invoices directly against purchase orders once received.',
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
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final invoice = shown[index];
                        return InvoiceCard(
                          invoice: invoice,
                          vendorName: procurementProvider.vendorName(
                            invoice.vendorId,
                          ),
                          onTap: () async {
                            await showFormSheet(
                              context,
                              () => InvoiceSheet(invoice: invoice),
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
