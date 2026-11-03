import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/units/widgets/unit_card.dart';
import 'package:inventory/src/ui/masters/units/widgets/unit_dialog.dart';
import 'package:provider/provider.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.units.isEmpty) {
        inventoryProvider.loadMasters();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    final allUnits = inventoryProvider.units;
    final theme = Theme.of(context);

    final filteredUnits = allUnits.where((unit) {
      if (_searchQuery.isEmpty) return true;
      return unit.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Units of measurement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: () => inventoryProvider.loadMasters(),
          ),
        ],
      ),
      floatingActionButton: canEdit && allUnits.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => UnitDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add unit'),
            )
          : null,
      body: inventoryProvider.isLoading && allUnits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => inventoryProvider.loadMasters(),
              child: allUnits.isEmpty
                  ? _EmptyUnitsView(
                      canEdit: canEdit,
                      onAddUnit: () => UnitDialog.show(context),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: SearchBar(
                                controller: _searchController,
                                hintText: 'Search units…',
                                leading: const Icon(Icons.search, size: 20),
                                trailing: [
                                  if (_searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: _clearSearch,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: Text(
                                '${filteredUnits.length} ${filteredUnits.length == 1 ? 'unit' : 'units'}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: filteredUnits.isEmpty
                                  ? _NoSearchResultsView(
                                      onClearSearch: _clearSearch,
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth >= 600;

                                        if (isWide) {
                                          return GridView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              88,
                                            ),
                                            gridDelegate:
                                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                                  maxCrossAxisExtent: 300,
                                                  mainAxisExtent: 68,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                ),
                                            itemCount: filteredUnits.length,
                                            itemBuilder: (context, index) {
                                              final unit = filteredUnits[index];
                                              return UnitCard(
                                                unit: unit,
                                                canEdit: canEdit,
                                                onEdit: (selectedUnit) =>
                                                    UnitDialog.show(
                                                      context,
                                                      unit: selectedUnit,
                                                    ),
                                              );
                                            },
                                          );
                                        }

                                        return ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            88,
                                          ),
                                          itemCount: filteredUnits.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final unit = filteredUnits[index];
                                            return UnitCard(
                                              unit: unit,
                                              canEdit: canEdit,
                                              onEdit: (selectedUnit) =>
                                                  UnitDialog.show(
                                                    context,
                                                    unit: selectedUnit,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _EmptyUnitsView extends StatelessWidget {
  const _EmptyUnitsView({required this.canEdit, required this.onAddUnit});

  final bool canEdit;
  final VoidCallback onAddUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.4,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.straighten_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No units yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create units of measurement to track inventory item quantities and stock.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  SeedDefaultsButton<InventoryProvider>(
                    label: 'Add default units',
                    canSeed: (provider) =>
                        provider.access.can('inventory.settings'),
                    seed: (provider) => provider.seedDefaults(),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddUnit,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add unit'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoSearchResultsView extends StatelessWidget {
  const _NoSearchResultsView({required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching units',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for a different unit name',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onClearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}
