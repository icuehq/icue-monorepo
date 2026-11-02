import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/vendor_card.dart';
import 'package:icueadmin/features/inventory/procurement/vendor_form_sheet.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Vendors (FRS 10.14). Directory of suppliers with category mapping and contact details.
class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.categories.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      if (mounted) await context.read<ProcurementProvider>().loadVendors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<ProcurementProvider>().loadVendors();

  Future<void> _toggle(InventoryVendor vendor) async {
    final procurementProvider = context.read<ProcurementProvider>();
    final result = await procurementProvider.setVendorActive(
      vendor.id,
      active: !vendor.active,
    );
    if (!mounted) return;
    if (result == null) {
      return showMessage(
        context,
        procurementProvider.errorMessage ?? 'Failed to update vendor status',
      );
    }
    await procurementProvider.loadVendors();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.vendors.manage');

    final allVendors = procurementProvider.vendors;
    final query = _searchController.text.trim().toLowerCase();

    final filteredVendors = allVendors.where((vendor) {
      if (_selectedFilter == 'active' && !vendor.active) return false;
      if (_selectedFilter == 'inactive' && vendor.active) return false;
      if (query.isNotEmpty) {
        final matchesName = vendor.name.toLowerCase().contains(query);
        final matchesCode = vendor.code.toLowerCase().contains(query);
        final matchesContact =
            vendor.contactPerson?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesCode && !matchesContact) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                await VendorFormSheet.show(context);
                if (mounted) await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Vendor'),
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vendors by name, code or contact…',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${allVendors.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'active',
                  'Active (${allVendors.where((v) => v.active).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'inactive',
                  'Inactive (${allVendors.where((v) => !v.active).length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Vendors List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: procurementProvider.isLoading && allVendors.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredVendors.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_mall_directory_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              query.isNotEmpty
                                  ? 'No vendors matching "$query"'
                                  : _selectedFilter == 'all'
                                  ? 'No vendors found'
                                  : 'No $_selectedFilter vendors',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              canEdit
                                  ? 'Add trusted suppliers to issue quotations and purchase orders.'
                                  : 'Vendors will appear here once added.',
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
                      itemCount: filteredVendors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final vendor = filteredVendors[index];
                        final categoryNames = [
                          for (final catId in vendor.categoryIds)
                            inventoryProvider.categories
                                    .where((category) => category.id == catId)
                                    .firstOrNull
                                    ?.name ??
                                catId,
                        ];

                        return VendorCard(
                          vendor: vendor,
                          categoryNames: categoryNames,
                          canEdit: canEdit,
                          onEdit: () async {
                            await VendorFormSheet.show(context, vendor: vendor);
                            if (mounted) await _load();
                          },
                          onToggleActive: () => _toggle(vendor),
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
    final selected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}
