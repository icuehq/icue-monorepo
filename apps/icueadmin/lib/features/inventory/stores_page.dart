import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/store_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class StoresPage extends StatefulWidget {
  const StoresPage({super.key});

  @override
  State<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  final _searchController = TextEditingController();
  int? _selectedCampus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.stores.isEmpty) {
        await inventoryProvider.loadMasters();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(BuildContext context, InventoryStore store) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.setStoreActive(
      store.id,
      active: !store.active,
    );
    if (!success && context.mounted) {
      showMessage(
        context,
        inventoryProvider.errorMessage ?? 'Failed to update store status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    final theme = Theme.of(context);
    final allStores = inventoryProvider.stores;

    final campuses = {for (final store in allStores) store.campusId}.toList()
      ..sort();

    final filteredStores = allStores.where((store) {
      if (_selectedCampus != null && store.campusId != _selectedCampus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = store.name.toLowerCase().contains(query);
        final matchCode = store.code.toLowerCase().contains(query);
        final matchLocation =
            store.location?.toLowerCase().contains(query) ?? false;
        final matchDescription =
            store.description?.toLowerCase().contains(query) ?? false;
        return matchName || matchCode || matchLocation || matchDescription;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.inventoryStoreForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add store'),
            )
          : null,
      body: inventoryProvider.isLoading && allStores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => inventoryProvider.loadMasters(),
              child: allStores.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 40,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No stores yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create stores to organize and track physical inventory across campuses.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (canEdit) ...[
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () =>
                                    context.push(AppRoutes.inventoryStoreForm),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Create first store'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: SearchBar(
                            controller: _searchController,
                            hintText: 'Search stores by name or location…',
                            leading: const Icon(Icons.search, size: 20),
                            trailing: [
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                            ],
                            elevation: const WidgetStatePropertyAll(0),
                            backgroundColor: WidgetStatePropertyAll(
                              theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value.trim()),
                          ),
                        ),
                        if (campuses.length > 1) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('All Campuses'),
                                  selected: _selectedCampus == null,
                                  onSelected: (_) =>
                                      setState(() => _selectedCampus = null),
                                ),
                                const SizedBox(width: 8),
                                for (final campusId in campuses) ...[
                                  FilterChip(
                                    label: Text('Campus $campusId'),
                                    selected: _selectedCampus == campusId,
                                    onSelected: (selected) => setState(
                                      () => _selectedCampus = selected
                                          ? campusId
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Text(
                            '${filteredStores.length} ${filteredStores.length == 1 ? 'store' : 'stores'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: filteredStores.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off_outlined,
                                          size: 48,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No matching stores',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Try clearing or modifying your search filter',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _selectedCampus = null;
                                            });
                                          },
                                          child: const Text('Clear filters'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    88,
                                  ),
                                  itemCount: filteredStores.length,
                                  itemBuilder: (context, index) {
                                    final store = filteredStores[index];
                                    return StoreCard(
                                      store: store,
                                      canEdit: canEdit,
                                      onEdit: (selectedStore) => context.push(
                                        AppRoutes.inventoryStoreForm,
                                        extra: selectedStore,
                                      ),
                                      onToggleActive: (selectedStore) =>
                                          _toggleActive(context, selectedStore),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
