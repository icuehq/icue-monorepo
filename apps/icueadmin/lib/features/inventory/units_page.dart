import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});

  Future<void> _add(BuildContext context) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final c = code.text.trim();
    final n = name.text.trim();
    code.dispose();
    name.dispose();
    if (ok != true || !context.mounted) return;
    final p = context.read<InventoryProvider>();
    if (c.isEmpty || n.isEmpty || !await p.saveUnit(c, n)) {
      if (context.mounted) {
        invSnack(context, p.errorMessage ?? 'Code and name are required');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Units of measurement')),
      floatingActionButton: p.access.can('inv.settings')
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Unit'),
            )
          : null,
      body: p.units.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : const SeedDefaultsButton(),
            )
          : ListView(
              children: [
                for (final u in p.units)
                  ListTile(title: Text(u.name), subtitle: Text(u.code)),
              ],
            ),
    );
  }
}
