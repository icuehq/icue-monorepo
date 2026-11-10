import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';

/// Why stock is being added: its label and a one-line explanation.
const _sources = {
  'opening': (
    'Existing stock',
    'Stock already in the store that is not in the system yet.',
  ),
  'return': (
    'Returned stock',
    'Items handed back to the store by a department or a person.',
  ),
};

/// Adds existing or returned stock to a store. Purchases are received on their
/// purchase order.
class ReceivePage extends StatefulWidget {
  const ReceivePage({this.storeId, super.key});

  final String? storeId;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _remarks = TextEditingController();
  final _lines = <LineDraft>[];
  final _requestId = newRequestId();
  late String? _store = widget.storeId;
  var _source = 'opening';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    _reference.dispose();
    _remarks.dispose();
    for (final lineDraft in _lines) {
      lineDraft.dispose();
    }
    super.dispose();
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
        'source': _source,
        'reference': _reference.text.trim(),
        'remarks': _remarks.text.trim(),
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
      appBar: AppBar(title: const Text('Receive Stock')),
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
                            'Store & source',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StoreDropdown(
                        value: _store,
                        onChanged: (value) => setState(() => _store = value),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Source of stock',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          for (final entry in _sources.entries)
                            ButtonSegment(
                              value: entry.key,
                              label: Text(entry.value.$1),
                            ),
                        ],
                        selected: {_source},
                        onSelectionChanged: (value) =>
                            setState(() => _source = value.first),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sources[_source]!.$2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      IcueTextField(
                        controller: _reference,
                        label: 'Reference (optional)',
                        maxLength: 50,
                        validator: (value) => (value ?? '').trim().length > 50
                            ? 'At most 50 characters'
                            : null,
                        hintText: 'e.g. OP-STOCK-2024, return slip number',
                        icon: Icons.tag_rounded,
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

              IcueTextField(
                controller: _remarks,
                label: 'Remarks / Notes (optional)',
                maxLength: 500,
                maxLines: 3,
                hintText: 'e.g. Verified by physical count',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),

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
