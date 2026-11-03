import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Stock verification sessions (FRS 10.21).
class VerificationsPage extends StatefulWidget {
  const VerificationsPage({super.key});

  @override
  State<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (mounted) {
      await context.read<InsightsProvider>().loadVerifications(
        inventoryProvider.access,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = context.watch<InsightsProvider>();
    final operate = context.read<InventoryProvider>().access.can(
      'inventory.stock.operate',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Stock verification')),
      floatingActionButton: operate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New'),
              onPressed: () async {
                await showFormPage(
                  context,
                  () => const _NewVerificationSheet(),
                );
                if (mounted) await _load();
              },
            )
          : null,
      body: insightsProvider.verifications.isEmpty
          ? Center(
              child: insightsProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      insightsProvider.errorMessage ??
                          'No verification sessions',
                    ),
            )
          : ListView(
              children: [
                for (final verification in insightsProvider.verifications)
                  ListTile(
                    title: Text(
                      '${verification.number} · ${verification.storeName}',
                    ),
                    subtitle: Text(
                      '${verification.date.toDisplayDay()} · ${verification.lineCount} lines'
                      '${verification.differenceCount == null ? '' : ' · ${verification.differenceCount} differences'}',
                    ),
                    trailing: Chip(
                      label: Text(humanizeStatus(verification.status)),
                    ),
                    onTap: () async {
                      await context.push(
                        InventoryRoutes.inventoryVerification,
                        extra: verification,
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
  final _categories = <String>{};
  var _busy = false;

  Future<void> _create() async {
    if (_storeId == null) return showMessage(context, 'Choose a store');
    setState(() => _busy = true);
    final insightsProvider = context.read<InsightsProvider>();
    final navigator = Navigator.of(context);
    final result = await insightsProvider.act('inventory-verification-create', {
      'storeId': _storeId,
      'categoryIds': _categories.toList(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      return showMessage(
        context,
        insightsProvider.errorMessage ?? 'Could not create',
      );
    }
    navigator.pop();
    showMessage(context, 'Created · ${result['number']}');
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<InventoryProvider>().topCategories;
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
          onChanged: (value) => setState(() => _storeId = value),
        ),
        const SizedBox(height: 12),
        const Text('Categories (none = whole store)'),
        Wrap(
          spacing: 8,
          children: [
            for (final category in categories)
              FilterChip(
                label: Text(category.name),
                selected: _categories.contains(category.id),
                onSelected: (isSelected) => setState(
                  () => isSelected
                      ? _categories.add(category.id)
                      : _categories.remove(category.id),
                ),
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
