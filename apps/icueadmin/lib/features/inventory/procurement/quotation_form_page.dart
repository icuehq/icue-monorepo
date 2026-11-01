import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Add a quotation to an approved request, or edit a draft ([existing]).
class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({required this.request, this.existing, super.key});

  final InventoryPurchaseRequest request;
  final InventoryQuotation? existing;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  final _form = GlobalKey<FormState>();
  late final _ref = TextEditingController(text: widget.existing?.vendorRef);
  late final _valid = TextEditingController(text: widget.existing?.validUntil);
  late final _days = TextEditingController(
    text: widget.existing?.deliveryDays?.toString(),
  );
  late final _remarks = TextEditingController(text: widget.existing?.remarks);
  late final _discount = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.discount),
  );
  late final _tax = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.tax),
  );
  late final _delivery = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.delivery),
  );
  final _lines = <OrderLineInput>[];
  late String? _vendor = widget.existing?.vendorId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final procurementProvider = context.read<ProcurementProvider>();
    if (procurementProvider.vendors.isEmpty) procurementProvider.loadVendors();
    final quotation = widget.existing;
    if (quotation != null) {
      for (final orderLine in quotation.lineItems) {
        _lines.add(
          OrderLineInput(
            orderLine.itemId,
            orderLine.variantId,
            procurementProvider.itemName(orderLine.itemId),
            quantity: formatQuantity(orderLine.quantity),
            price: formatQuantity(orderLine.unitPrice),
          ),
        );
      }
    } else {
      for (final purchaseRequestLine in widget.request.lineItems) {
        _lines.add(
          OrderLineInput(
            purchaseRequestLine.itemId,
            purchaseRequestLine.variantId,
            procurementProvider.itemName(purchaseRequestLine.itemId),
            quantity: formatQuantity(purchaseRequestLine.quantity),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _ref,
      _valid,
      _days,
      _remarks,
      _discount,
      _tax,
      _delivery,
    ]) {
      controller.dispose();
    }
    for (final orderLineInput in _lines) {
      orderLineInput.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save({required bool finalize}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Keep at least one item');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act('inventory-quotation-save', {
            'id': ?widget.existing?.id,
            'purchaseRequestId': widget.request.id,
            'vendorId': _vendor,
            'vendorRef': _ref.text.trim(),
            'validUntil': _valid.text,
            'deliveryDays': int.tryParse(_days.text.trim()),
            'lineItems': [
              for (final orderLineInput in _lines)
                orderLineInput.toJson('quantity'),
            ],
            'discount': _v(_discount),
            'tax': _v(_tax),
            'delivery': _v(_delivery),
            'remarks': _remarks.text.trim(),
            'final': finalize,
          }),
      done: finalize ? 'Quotation recorded' : 'Draft saved',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final vendors = context.watch<ProcurementProvider>().vendors.where(
      (vendor) => vendor.active || vendor.id == _vendor,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing?.number ?? 'Quotation · ${widget.request.number}',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vendor,
              decoration: const InputDecoration(labelText: 'Vendor *'),
              items: [
                for (final vendor in vendors)
                  DropdownMenuItem(value: vendor.id, child: Text(vendor.name)),
              ],
              onChanged: (value) => _vendor = value,
              validator: (value) => value == null ? 'Required' : null,
            ),
            TextFormField(
              controller: _ref,
              decoration: const InputDecoration(
                labelText: "Vendor's quotation no.",
              ),
            ),
            dateField(context, _valid, 'Valid until *'),
            TextFormField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delivery (days)'),
            ),
            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 12),
            for (final (n, l) in _lines.indexed)
              OrderLineCard(
                line: l,
                onChanged: () => setState(() {}),
                onRemove: _lines.length > 1
                    ? () => setState(() => _lines.removeAt(n).dispose())
                    : null,
              ),
            OrderTotals(
              lineItems: _lines,
              discount: _discount,
              tax: _tax,
              delivery: _delivery,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _save(finalize: true),
              child: Text(_busy ? 'Saving…' : 'Record quotation'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(finalize: false),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
  }
}
