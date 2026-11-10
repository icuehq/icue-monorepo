import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';

const _sources = {
  'opening': 'Opening stock',
  'adjustment': 'Authorised adjustment',
  'department_return': 'Department return',
  'person_return': 'Staff/student return',
  'other': 'Other authorised receipt',
};

/// Stock receiving (FRS 10.7). Purchase-order receiving arrives with Inv-5.
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
                            'Destination & Source',
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
                      IcueDropdown<String>(
                        value: _source,
                        items: [
                          for (final mapEntry in _sources.entries)
                            DropdownMenuItem(
                              value: mapEntry.key,
                              child: Text(
                                mapEntry.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _source = value!),
                        label: 'Source of stock',
                        icon: Icons.source_outlined,
                      ),
                      const SizedBox(height: 12),
                      IcueTextField(
                        controller: _reference,
                        label: 'Reference number / Challan (optional)',
                        hintText: 'e.g. DC-2024-001, OP-STOCK-2024',
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
                            'Items to Receive',
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
        for (final lineDraft in lines) ...[
          lineDraft.quantity,
          lineDraft.rejected,
          lineDraft.cost,
        ],
      ]),
      builder: (context, _) {
        double totalAccepted = 0;
        double totalRejected = 0;
        double totalValuation = 0;
        var hasValuation = false;

        for (final lineDraft in lines) {
          final accepted = double.tryParse(lineDraft.quantity.text.trim()) ?? 0;
          final rejected = double.tryParse(lineDraft.rejected.text.trim()) ?? 0;
          final unitCost = double.tryParse(lineDraft.cost.text.trim());
          totalAccepted += accepted;
          totalRejected += rejected;
          if (unitCost != null && unitCost > 0 && accepted > 0) {
            totalValuation += accepted * unitCost;
            hasValuation = true;
          }
        }

        if (totalAccepted == 0 && totalRejected == 0 && !hasValuation) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Accepted: ${totalAccepted.toQuantityText()}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (totalRejected > 0)
                      Text(
                        'Rejected: ${totalRejected.toQuantityText()}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    if (hasValuation)
                      Text(
                        'Total Value: ${totalValuation.toRupees()}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
