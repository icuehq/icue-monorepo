import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_receive_line_card.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One delivery against a purchase order: accepted and rejected quantities per line (FRS 10.17).
class PurchaseOrderReceivePage extends StatefulWidget {
  const PurchaseOrderReceivePage({required this.order, super.key});

  final InventoryPurchaseOrder order;

  @override
  State<PurchaseOrderReceivePage> createState() =>
      _PurchaseOrderReceivePageState();
}

class _PurchaseOrderReceivePageState extends State<PurchaseOrderReceivePage> {
  final _form = GlobalKey<FormState>();
  final _deliveryRef = TextEditingController();
  final _remarks = TextEditingController();
  final _requestId = newRequestId();
  late final _drafts = [
    for (final orderLine in widget.order.lineItems.where(
      (orderLine) => orderLine.due > 0,
    ))
      ReceiveLineDraft(orderLine),
  ];
  String? _store;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    _deliveryRef.dispose();
    _remarks.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _acceptAllDue() {
    setState(() {
      for (final draft in _drafts) {
        if (draft.line.due > 0) {
          draft.accepted.text = formatQuantity(draft.line.due);
          draft.rejected.clear();
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final draft in _drafts) {
        draft.accepted.clear();
        draft.rejected.clear();
      }
    });
  }

  Future<void> _save() async {
    if (_store == null) {
      return showMessage(context, 'Please select a destination store');
    }
    if (!_form.currentState!.validate()) return;
    final lineItems = _drafts.where((draft) => draft.touched).toList();
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter an accepted or rejected quantity');
    }
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act('inventory-purchaseOrder-receive', {
            'purchaseOrderId': widget.order.id,
            'storeId': _store,
            'deliveryRef': _deliveryRef.text.trim(),
            'remarks': _remarks.text.trim(),
            'lineItems': [for (final draft in lineItems) draft.toJson()],
          }, requestId: _requestId),
      done: 'Goods received (GRN generated)',
    );
    if (mounted) setState(() => _busy = false);
  }

  String? _validateQuantity(String? currentValue, ReceiveLineDraft draft) {
    final value = (currentValue ?? '').trim();
    if (value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null || number < 0) return 'Invalid';
    return draft.acceptedValue + draft.rejectedValue > draft.line.due
        ? 'Only ${formatQuantity(draft.line.due)} due'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    final theme = Theme.of(context);
    final purchaseOrder = widget.order;
    final acceptedCount = _drafts
        .where((draft) => draft.acceptedValue > 0)
        .length;

    return Scaffold(
      appBar: AppBar(title: Text('Receive ${purchaseOrder.number}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          purchaseOrder.number,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            purchaseOrder.status.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            procurementProvider.vendorName(
                              purchaseOrder.vendorId,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expected by: ${purchaseOrder.expectedDate}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Store & Challan
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination & Delivery Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StoreDropdown(
                      value: _store,
                      campusId: purchaseOrder.deliveryCampusId,
                      onChanged: (value) => setState(() => _store = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deliveryRef,
                      decoration: const InputDecoration(
                        labelText: 'Delivery note / Challan no. (optional)',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Items to Receive',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_drafts.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _acceptAllDue,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Accept all due'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Clear quantities',
                      onPressed: _clearAll,
                      icon: const Icon(Icons.clear_all_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            for (final draft in _drafts)
              PurchaseOrderReceiveLineCard(
                draft: draft,
                itemName: procurementProvider.itemName(draft.line.itemId),
                isBatchTracked:
                    procurementProvider.items[draft.line.itemId]?.tracking ==
                    Tracking.batch,
                onChanged: () => setState(() {}),
                validator: _validateQuantity,
              ),

            const SizedBox(height: 8),
            TextFormField(
              controller: _remarks,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Overall inspection remarks (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.inventory_2_rounded),
              label: Text(
                _busy
                    ? 'Saving…'
                    : acceptedCount > 0
                    ? 'Confirm receiving ($acceptedCount ${acceptedCount == 1 ? "item" : "items"})'
                    : 'Confirm receiving',
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
