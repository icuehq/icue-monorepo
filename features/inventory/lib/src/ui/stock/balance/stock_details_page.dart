import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/balance/widgets/balance_sheets.dart';
import 'package:provider/provider.dart';

/// Everything about one stock balance (a store × item × variant × batch):
/// quantities, item and batch details, actions and the movement history.
class StockDetailsPage extends StatefulWidget {
  const StockDetailsPage({required this.balanceId, super.key});

  final String balanceId;

  @override
  State<StockDetailsPage> createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> {
  /// Bumped after an action so the movement history reloads.
  var _historyVersion = 0;

  Future<void> _open(Widget Function() form) async {
    await showFormPage(context, form);
    if (mounted) setState(() => _historyVersion++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.watch<StockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final balance = stockProvider.balances
        .where((row) => row.id == widget.balanceId)
        .firstOrNull;
    if (balance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock details')),
        body: Center(
          child: stockProvider.isLoading
              ? const CircularProgressIndicator()
              : const Text('This stock line is no longer in the list.'),
        ),
      );
    }
    final item = stockProvider.items[balance.itemId];
    final operate = inventoryProvider.access.can('inventory.stock.operate');
    final unit = item?.stockUnit ?? '';
    String quantity(double value) => unit.isEmpty
        ? value.toQuantityText()
        : '${value.toQuantityText()} $unit';

    final tiles = [
      ('Available', quantity(balance.available), null),
      ('Damaged', quantity(balance.damaged), null),
      ('Expired', quantity(balance.expired), null),
      ('Received', quantity(balance.receivedTotal), null),
      ('Issued', quantity(balance.issuedTotal), null),
      ('Value', balance.value.toRupees(), null),
    ];

    final detailRows = <Widget>[
      _InfoRow(
        'Category',
        inventoryProvider.category(item?.categoryId)?.name ?? '—',
      ),
      _InfoRow('Unit', item?.stockUnit ?? '—'),
      _InfoRow('Tracking', item?.tracking.label ?? '—'),
      _InfoRow('Store', stockProvider.store?.name ?? '—'),
      if (balance.variantId != null) _InfoRow('Variant', balance.variantId!),
      if (balance.batchNumber != null)
        _InfoRow('Batch number', balance.batchNumber!),
      if (balance.expiryDate != null)
        _InfoRow('Expiry date', balance.expiryDate!.toDisplayDay()),
      _InfoRow(
        'Reorder level',
        item?.reorderLevel == null ? '—' : quantity(item!.reorderLevel!),
      ),
      _InfoRow('Default price', item?.defaultPrice?.toRupees() ?? '—'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Stock details')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= IcueBreakpoints.wide;
          final columns = width >= 1100 ? 6 : (width >= 600 ? 3 : 2);
          final tileWidth = (width - 32 - 12 * (columns - 1)) / columns;
          final details = _Section(
            title: 'Details',
            child: Column(children: detailRows),
          );
          final history = _Section(
            title: 'Movement history',
            child: MovementHistory(balance, key: ValueKey(_historyVersion)),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stockProvider.itemName(balance.itemId),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            ?stockProvider.store?.name,
                            if (balance.batchNumber != null)
                              'Batch ${balance.batchNumber}',
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (balance.isBelowReorderLevel)
                    Chip(
                      avatar: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      label: const Text('Low stock'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (label, value, _) in tiles)
                    _StatTile(
                      width: tileWidth,
                      label: label,
                      value: value,
                      highlight:
                          label == 'Available' && balance.isBelowReorderLevel,
                    ),
                ],
              ),
              if (operate) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IcueButton(
                      label: 'Adjust quantity',
                      leadingIcon: Icons.tune_rounded,
                      onPressed: () => _open(() => AdjustStockForm(balance)),
                    ),
                    IcueButton(
                      label: 'Report damaged / expired / lost',
                      leadingIcon: Icons.report_problem_outlined,
                      variant: IcueButtonVariant.outline,
                      onPressed: () => _open(() => ReportStockForm(balance)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: details),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: history),
                      ],
                    )
                  : Column(
                      children: [details, const SizedBox(height: 16), history],
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final double width;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
