import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/units/widgets/unit_card.dart';
import 'package:inventory/src/ui/masters/units/widgets/unit_dialog.dart';
import 'package:inventory/src/ui/masters/units/widgets/units_table.dart';
import 'package:provider/provider.dart';

/// Units of measurement: a table on wide screens, searchable cards on phones.
class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.units.isEmpty) inventoryProvider.loadMasters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    final allUnits = inventoryProvider.units;
    final wide = context.isWide;
    final filteredUnits = [
      for (final unit in allUnits)
        if (unit.name.toLowerCase().contains(_searchQuery.toLowerCase())) unit,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Units of measurement')),
      floatingActionButton: canEdit && allUnits.isNotEmpty && !wide
          ? FloatingActionButton.extended(
              onPressed: () => UnitDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add unit'),
            )
          : null,
      body: inventoryProvider.isLoading && allUnits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : allUnits.isEmpty
          ? _EmptyUnitsView(
              canEdit: canEdit,
              onAddUnit: () => UnitDialog.show(context),
            )
          : wide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: UnitsTable(units: allUnits, canEdit: canEdit),
            )
          : RefreshIndicator(
              onRefresh: inventoryProvider.loadMasters,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SearchBar(
                      hintText: 'Search units…',
                      leading: const Icon(Icons.search, size: 20),
                      elevation: const WidgetStatePropertyAll(0),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                    ),
                  ),
                  Expanded(
                    child: filteredUnits.isEmpty
                        ? const Center(child: Text('No matching units'))
                        : IcueAdaptiveCardList(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            spacing: 8,
                            itemCount: filteredUnits.length,
                            itemBuilder: (context, index) => UnitCard(
                              unit: filteredUnits[index],
                              canEdit: canEdit,
                              onEdit: (unit) =>
                                  UnitDialog.show(context, unit: unit),
                            ),
                          ),
                  ),
                ],
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
                  IcueSeedDefaultsButton<InventoryProvider>(
                    label: 'Add default units',
                    canSeed: (provider) =>
                        provider.access.can('inventory.settings'),
                    seed: (provider) => provider.seedDefaults(),
                  ),
                  IcueButton(
                    label: 'Add unit',
                    onPressed: onAddUnit,
                    variant: IcueButtonVariant.outline,
                    leadingIcon: Icons.add_rounded,
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
