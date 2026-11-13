import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Adds stock to a store. Purchases are received on their
/// purchase order.
class ReceivePage extends StatefulWidget {
  const ReceivePage({this.storeId, super.key});

  final String? storeId;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final _form = GlobalKey<FormState>();
  final _lines = <LineDraft>[];
  final _requestId = newRequestId();
  late String? _store = widget.storeId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    for (final lineDraft in _lines) {
      lineDraft.dispose();
    }
    super.dispose();
  }

  /// Debug only: fills the form from the first loaded items and store.
  Future<void> _fillSample() async {
    final inventory = context.read<InventoryProvider>();
    if (inventory.stores.isEmpty) await inventory.loadMasters();
    await inventory.loadItems(search: '', clearCategory: true);
    if (!mounted) return;
    final store = inventory.stores.where((store) => store.active).firstOrNull;
    // Asset-tracked items are not received here (the item picker hides them too).
    final items = inventory.items
        .where((item) => item.active && item.tracking != Tracking.asset)
        .take(3);
    if (store == null || items.isEmpty) {
      return showMessage(
        context,
        inventory.errorMessage ?? 'No active store or stock item found',
      );
    }
    final drafts = <LineDraft>[];
    for (final item in items) {
      final variants = await inventory.variants(item.id);
      final variant = variants.where((variant) => variant.active).firstOrNull;
      final lineDraft = LineDraft(item, variant);
      lineDraft.quantity.text = '${10 * (drafts.length + 1)}';
      lineDraft.cost.text = '${item.defaultPrice ?? 50 + 25 * drafts.length}';
      if (item.tracking == Tracking.batch) {
        lineDraft.batchNumber.text = 'BATCH-${drafts.length + 1}';
        lineDraft.expiry.text = '2027-12-31';
      }
      drafts.add(lineDraft);
    }
    if (!mounted) return;
    setState(() {
      _store = store.id;
      for (final lineDraft in _lines) {
        lineDraft.dispose();
      }
      _lines
        ..clear()
        ..addAll(drafts);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Add at least one item');
    final seen = <String>{};
    for (final lineDraft in _lines) {
      final batch = lineDraft.item.tracking == Tracking.batch
          ? lineDraft.batchNumber.text.trim()
          : '';
      final key = '${lineDraft.item.id}|${lineDraft.variant?.id}|$batch';
      if (!seen.add(key)) {
        final name = lineDraft.item.name;
        return showMessage(
          context,
          batch.isEmpty
              ? '$name is added twice. Combine it into one line.'
              : '$name batch $batch is added twice. Combine it into one line.',
        );
      }
    }
    setState(() => _busy = true);
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-receipt-confirm', {
        'storeId': _store,
        'lineItems': [
          for (final lineDraft in _lines)
            lineDraft.toMap(
              quantityKey: 'quantityAccepted',
              batch: true,
              receipt: true,
            ),
        ],
      }, requestId: _requestId),
      done: 'Stock received successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Stock'),
        actions: [
          if (!ApiEnvironment.fromEnvironment().isProd)
            IcueButton(
              label: 'Fill sample',
              onPressed: _fillSample,
              variant: IcueButtonVariant.secondary,
              size: IcueButtonSize.small,
            ),
        ],
      ),
      body: IcueCenteredBody(
        maxWidth: 900,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Store & Source Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warehouse_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Store',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StoreDropdown(
                        // initialValue is read once; rebuild when a fill changes the store.
                        key: ValueKey(_store),
                        value: _store,
                        onChanged: (value) => setState(() => _store = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Items',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_lines.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_lines.length} ${_lines.length == 1 ? 'item' : 'items'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LineEditor(
                        lineItems: _lines,
                        receipt: true,
                        onChanged: () => setState(() {}),
                      ),
                      if (_lines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReceiveSummaryBar(lines: _lines),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              IcueButton(
                label: _busy ? 'Receiving…' : 'Confirm Receiving',
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.check_circle_outline_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiveSummaryBar extends StatelessWidget {
  const _ReceiveSummaryBar({required this.lines});

  final List<LineDraft> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        for (final lineDraft in lines) ...[lineDraft.quantity, lineDraft.cost],
      ]),
      builder: (context, _) {
        var totalQuantity = 0.0;
        var totalValue = 0.0;
        for (final lineDraft in lines) {
          final quantity = double.tryParse(lineDraft.quantity.text.trim()) ?? 0;
          final unitCost = double.tryParse(lineDraft.cost.text.trim()) ?? 0;
          totalQuantity += quantity;
          totalValue += quantity * unitCost;
        }
        if (totalQuantity == 0) return const SizedBox.shrink();
        final style = theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                'Total quantity: ${totalQuantity.toQuantityText()}',
                style: style,
              ),
              const Spacer(),
              if (totalValue > 0)
                Text('Value: ${totalValue.toRupees()}', style: style),
            ],
          ),
        );
      },
    );
  }
}
