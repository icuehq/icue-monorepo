import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Stock verification sessions (FRS 10.21).
class VerificationsPage extends StatefulWidget {
  const VerificationsPage({super.key});

  @override
  State<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.stores.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<InsightsProvider>().loadVerifications(inv.access);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsightsProvider>();
    final operate = context.read<InventoryProvider>().access.can(
      'inv.stock.operate',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Stock verification')),
      floatingActionButton: operate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New'),
              onPressed: () async {
                await showInvSheet(
                  context,
                  () => const _NewVerificationSheet(),
                );
                if (mounted) await _load();
              },
            )
          : null,
      body: p.verifications.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'No verification sessions'),
            )
          : ListView(
              children: [
                for (final v in p.verifications)
                  ListTile(
                    title: Text('${v.number} · ${v.storeName}'),
                    subtitle: Text(
                      '${v.date} · ${v.lineCount} lines'
                      '${v.diffCount == null ? '' : ' · ${v.diffCount} differences'}',
                    ),
                    trailing: Chip(label: Text(statusLabel(v.status))),
                    onTap: () async {
                      await context.push(
                        AppRoutes.inventoryVerification,
                        extra: v,
                      );
                      if (mounted) await _load();
                    },
                  ),
              ],
            ),
    );
  }
}

class _NewVerificationSheet extends StatefulWidget {
  const _NewVerificationSheet();

  @override
  State<_NewVerificationSheet> createState() => _NewVerificationSheetState();
}

class _NewVerificationSheetState extends State<_NewVerificationSheet> {
  String? _storeId;
  final _cats = <String>{};
  var _busy = false;

  Future<void> _create() async {
    if (_storeId == null) return invSnack(context, 'Choose a store');
    setState(() => _busy = true);
    final p = context.read<InsightsProvider>();
    final nav = Navigator.of(context);
    final res = await p.act('inv-verification-create', {
      'storeId': _storeId,
      'categoryIds': _cats.toList(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      return invSnack(context, p.errorMessage ?? 'Could not create');
    }
    nav.pop();
    invSnack(context, 'Created · ${res['number']}');
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<InventoryProvider>().topCategories;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New verification',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        StoreDropdown(
          value: _storeId,
          onChanged: (v) => setState(() => _storeId = v),
        ),
        const SizedBox(height: 12),
        const Text('Categories (none = whole store)'),
        Wrap(
          spacing: 8,
          children: [
            for (final c in cats)
              FilterChip(
                label: Text(c.name),
                selected: _cats.contains(c.id),
                onSelected: (on) =>
                    setState(() => on ? _cats.add(c.id) : _cats.remove(c.id)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: const Text('Generate expected stock'),
        ),
      ],
    );
  }
}
