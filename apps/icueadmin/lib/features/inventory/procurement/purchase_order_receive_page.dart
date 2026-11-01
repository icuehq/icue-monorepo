import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class _Draft {
  _Draft(this.line);

  final OrderLine line;
  final accepted = TextEditingController();
  final rejected = TextEditingController();
  final condition = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();

  double get acceptedValue => double.tryParse(accepted.text.trim()) ?? 0;
  double get rejectedValue => double.tryParse(rejected.text.trim()) ?? 0;
  bool get touched => acceptedValue + rejectedValue > 0;

  void dispose() {
    for (final controller in [
      accepted,
      rejected,
      condition,
      batchNumber,
      expiry,
    ]) {
      controller.dispose();
    }
  }

  Map<String, Object?> toJson() {
    String? text(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return {
      'itemId': line.itemId,
      'variantId': ?line.variantId,
      'quantityAccepted': acceptedValue,
      'quantityRejected': rejectedValue,
      'condition': text(condition),
      'batchNumber': text(batchNumber),
      'expiryDate': text(expiry),
    };
  }
}

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
      _Draft(orderLine),
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final lineItems = _drafts.where((draft) => draft.touched).toList();
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter a received quantity');
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
      done: 'Received',
    );
    if (mounted) setState(() => _busy = false);
  }

  String? _validateQuantity(String? currentValue, _Draft draft) {
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
    final purchaseOrder = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Receive ${purchaseOrder.number}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${procurementProvider.vendorName(purchaseOrder.vendorId)} · due ${purchaseOrder.expectedDate}',
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
                labelText: 'Delivery note / challan no. (optional)',
              ),
            ),
            const SizedBox(height: 12),
            for (final draft in _drafts)
              _line(context, procurementProvider, draft),
            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(
                labelText: 'Inspection remarks (optional)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Confirm receiving'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    ProcurementProvider procurementProvider,
    _Draft draft,
  ) {
    final batch =
        procurementProvider.items[draft.line.itemId]?.tracking ==
        Tracking.batch;
    const num = TextInputType.numberWithOptions(decimal: true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              procurementProvider.itemName(draft.line.itemId),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Ordered ${formatQuantity(draft.line.quantity)} · still due ${formatQuantity(draft.line.due)}',
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.accepted,
                    keyboardType: num,
                    decoration: const InputDecoration(labelText: 'Accepted'),
                    validator: (value) => _validateQuantity(value, draft),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: draft.rejected,
                    keyboardType: num,
                    decoration: const InputDecoration(labelText: 'Rejected'),
                    validator: (value) => _validateQuantity(value, draft),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: draft.condition,
              decoration: const InputDecoration(
                labelText: 'Condition (optional)',
              ),
            ),
            if (batch)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: draft.batchNumber,
                      decoration: const InputDecoration(labelText: 'Batch no.'),
                      validator: (value) =>
                          draft.touched && (value ?? '').trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _expiry(context, draft.expiry)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _expiry(BuildContext context, TextEditingController controller) =>
      TextFormField(
        controller: controller,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Expiry',
          suffixIcon: Icon(Icons.event_rounded),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: DateTime.now(),
          );
          if (date != null) {
            controller.text = date.toIso8601String().substring(0, 10);
          }
        },
      );
}
