import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/vendors/vendor_actions.dart';
import 'package:inventory/src/ui/procurement/vendors/widgets/vendor_card.dart';
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
  String? _categoryId;

  /// False until the first fetch ends, so an earlier visit's rows never flash.
  var _loaded = false;

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

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) await context.read<ProcurementProvider>().loadVendors();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  bool _matches(InventoryVendor vendor, String query) {
    if (_selectedFilter == 'active' && !vendor.active) return false;
    if (_selectedFilter == 'inactive' && vendor.active) return false;
    if (_categoryId != null && !vendor.categoryIds.contains(_categoryId)) {
      return false;
    }
    if (query.isEmpty) return true;
    return [
      vendor.name,
      vendor.contactPerson,
      vendor.phone,
      vendor.email,
      vendor.taxNumber,
    ].any((field) => field?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.vendors.manage');

    final allVendors = procurementProvider.vendors;
    final query = _searchController.text.trim().toLowerCase();
    final filteredVendors = [
      for (final vendor in allVendors)
        if (_matches(vendor, query)) vendor,
    ];
    final usedCategories = [
      for (final category in inventoryProvider.categories)
        if (allVendors.any(
          (vendor) => vendor.categoryIds.contains(category.id),
        ))
          category,
    ];
    final failure = procurementProvider.errorMessage;
    final filtering =
        query.isNotEmpty || _selectedFilter != 'all' || _categoryId != null;

    String categoryName(String id) =>
        inventoryProvider.categories
            .where((category) => category.id == id)
            .firstOrNull
            ?.name ??
        id;

    Widget empty() => Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              failure != null
                  ? 'Could not load vendors'
                  : filtering
                  ? 'No vendors match your filters'
                  : 'No vendors yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              failure ??
                  (canEdit
                      ? 'Add trusted suppliers to issue quotations and purchase orders.'
                      : 'Vendors will appear here once added.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (failure != null)
              IcueButton(
                label: 'Try again',
                onPressed: _load,
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.refresh,
              )
            else if (filtering)
              IcueButton(
                label: 'Clear filters',
                onPressed: () => setState(() {
                  _searchController.clear();
                  _selectedFilter = 'all';
                  _categoryId = null;
                }),
                variant: IcueButtonVariant.outline,
              )
            else if (canEdit)
              IcueButton(
                label: 'New vendor',
                onPressed: () => _open(InventoryRoutes.inventoryVendorForm),
                leadingIcon: Icons.add,
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _open(InventoryRoutes.inventoryVendorForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New vendor'),
            )
          : null,
      body: IcueCenteredBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, contact, phone or GST…',
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (key, label, count) in [
                    ('all', 'All', allVendors.length),
                    (
                      'active',
                      'Active',
                      allVendors.where((vendor) => vendor.active).length,
                    ),
                    (
                      'inactive',
                      'Inactive',
                      allVendors.where((vendor) => !vendor.active).length,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$label ($count)'),
                        selected: _selectedFilter == key,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = key),
                      ),
                    ),
                  if (usedCategories.isNotEmpty) ...[
                    const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                    for (final category in usedCategories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          showCheckmark: false,
                          onSelected: (selected) => setState(
                            () => _categoryId = selected ? category.id : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child:
                    !_loaded ||
                        (procurementProvider.isLoading && allVendors.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : filteredVendors.isEmpty
                    ? empty()
                    : IcueAdaptiveList<InventoryVendor>(
                        items: filteredVendors,
                        onTap: (vendor) => _open(
                          '${InventoryRoutes.inventoryVendorDetail}?id=${vendor.id}',
                        ),
                        columns: [
                          IcueAdaptiveColumn(
                            label: 'Vendor',
                            flex: 2,
                            cell: (context, vendor) => Row(
                              children: [
                                if (!vendor.active) const IcueInactiveBadge(),
                                Flexible(child: Text(vendor.name)),
                              ],
                            ),
                          ),
                          IcueAdaptiveColumn.text(
                            'Contact',
                            (vendor) => vendor.contactPerson ?? '—',
                          ),
                          IcueAdaptiveColumn.text(
                            'Phone',
                            (vendor) => vendor.phone ?? '—',
                          ),
                          IcueAdaptiveColumn.text(
                            'Email',
                            (vendor) => vendor.email ?? '—',
                            flex: 2,
                          ),
                          IcueAdaptiveColumn.text(
                            'Categories',
                            (vendor) =>
                                vendor.categoryIds.map(categoryName).join(', '),
                            flex: 2,
                          ),
                          IcueAdaptiveColumn(
                            label: '',
                            width: 96,
                            cell: (context, vendor) => canEdit
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _open(
                                          '${InventoryRoutes.inventoryVendorForm}?id=${vendor.id}',
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: vendor.active
                                            ? 'Deactivate'
                                            : 'Activate',
                                        icon: Icon(
                                          vendor.active
                                              ? Icons.toggle_on_rounded
                                              : Icons.toggle_off_rounded,
                                        ),
                                        onPressed: () =>
                                            toggleVendorActive(context, vendor),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                        cardBuilder: (context, vendor) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: VendorCard(
                            vendor: vendor,
                            categoryNames: [
                              for (final id in vendor.categoryIds)
                                categoryName(id),
                            ],
                            canEdit: canEdit,
                            onTap: () => _open(
                              '${InventoryRoutes.inventoryVendorDetail}?id=${vendor.id}',
                            ),
                            onEdit: () => _open(
                              '${InventoryRoutes.inventoryVendorForm}?id=${vendor.id}',
                            ),
                            onToggleActive: () =>
                                toggleVendorActive(context, vendor),
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
}
