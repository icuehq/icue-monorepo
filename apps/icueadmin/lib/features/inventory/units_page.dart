import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});

  Future<void> _add(BuildContext context) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Code (e.g. bag)'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final currentValue = code.text.trim();
    final value = name.text.trim();
    code.dispose();
    name.dispose();
    if (ok != true || !context.mounted) return;
    final inventoryProvider = context.read<InventoryProvider>();
    if (currentValue.isEmpty ||
        value.isEmpty ||
        !await inventoryProvider.saveUnit(currentValue, value)) {
      if (context.mounted) {
        showMessage(
          context,
          inventoryProvider.errorMessage ?? 'Code and name are required',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Units of measurement')),
      floatingActionButton: inventoryProvider.access.can('inventory.settings')
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Unit'),
            )
          : null,
      body: inventoryProvider.units.isEmpty
          ? Center(
              child: inventoryProvider.isLoading
                  ? const CircularProgressIndicator()
                  : SeedDefaultsButton<InventoryProvider>(
                      label: 'Add default categories & units',
                      canSeed: (provider) =>
                          provider.access.can('inventory.settings'),
                      seed: (provider) => provider.seedDefaults(),
                    ),
            )
          : ListView(
              children: [
                for (final unit in inventoryProvider.units)
                  ListTile(title: Text(unit.name), subtitle: Text(unit.code)),
              ],
            ),
    );
  }
}
