import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Draft a PO against an approved request, from a [quotation] (vendor and prices fixed) or directly.
/// With [existing], edits that draft.
class PurchaseOrderFormPage extends StatefulWidget {
  const PurchaseOrderFormPage({
    required this.request,
    this.quotation,
    this.existing,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final InventoryQuotation? quotation;
  final InventoryPurchaseOrder? existing;

  @override
  State<PurchaseOrderFormPage> createState() => _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState extends State<PurchaseOrderFormPage> {
  final _form = GlobalKey<FormState>();
  late final _expected = TextEditingController(
    text: widget.existing?.expectedDate,
  );
  late final _terms = TextEditingController(text: widget.existing?.terms);
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
  late String? _vendor =
      widget.existing?.vendorId ?? widget.quotation?.vendorId;
  late int _campus =
      widget.existing?.deliveryCampusId ?? widget.request.campusId;
  var _busy = false;

  String? get _quotationId =>
      widget.existing?.quotationId ?? widget.quotation?.id;

  @override
  void initState() {
    super.initState();
    final procurementProvider = context.read<ProcurementProvider>();
    if (procurementProvider.vendors.isEmpty) procurementProvider.loadVendors();
    final locked = _quotationId != null;
    OrderLineInput add(
      String item,
      String? variant,
      double quantity,
      double price,
    ) => OrderLineInput(
      item,
      variant,
      procurementProvider.itemName(item),
      quantity: formatQuantity(quantity),
      price: price == 0 ? '' : formatQuantity(price),
      priceLocked: locked,
    );
    final purchaseOrder = widget.existing;
    final quote = widget.quotation;
    if (purchaseOrder != null) {
      for (final orderLine in purchaseOrder.lineItems) {
        _lines.add(
          add(
            orderLine.itemId,
            orderLine.variantId,
            orderLine.quantity,
            orderLine.unitPrice,
          ),
        );
      }
    } else if (quote != null) {
      for (final orderLine in quote.lineItems) {
        final left = widget.request.lineItems
            .where(
              (purchaseRequestLine) =>
                  purchaseRequestLine.itemId == orderLine.itemId &&
                  purchaseRequestLine.variantId == orderLine.variantId,
            )
            .map(
              (purchaseRequestLine) =>
                  purchaseRequestLine.quantity -
                  purchaseRequestLine.quantityOrdered,
            );
        final quantity = left.isEmpty || left.first > orderLine.quantity
            ? orderLine.quantity
            : left.first;
        if (quantity > 0) {
          _lines.add(
            add(
              orderLine.itemId,
              orderLine.variantId,
              quantity,
              orderLine.unitPrice,
            ),
          );
        }
      }
    } else {
      for (final purchaseRequestLine in widget.request.lineItems) {
        if (purchaseRequestLine.quantity >
            purchaseRequestLine.quantityOrdered) {
          _lines.add(
            add(
              purchaseRequestLine.itemId,
              purchaseRequestLine.variantId,
              purchaseRequestLine.quantity -
                  purchaseRequestLine.quantityOrdered,
              purchaseRequestLine.estimatedPrice,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _expected,
      _terms,
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

  Future<void> _save({required bool issue}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Nothing left to order');
    setState(() => _busy = true);
    await procSubmit(context, (procurementProvider) async {
      final saved = await procurementProvider.act(
        'inventory-purchaseOrder-save',
        {
          'id': ?widget.existing?.id,
          'purchaseRequestId': widget.request.id,
          'quotationId': ?_quotationId,
          'vendorId': _vendor,
          'deliveryCampusId': _campus,
          'expectedDate': _expected.text,
          'terms': _terms.text.trim(),
          'remarks': _remarks.text.trim(),
          'lineItems': [
            for (final orderLineInput in _lines)
              orderLineInput.toJson('quantityOrdered'),
          ],
          'discount': _v(_discount),
          'tax': _v(_tax),
          'delivery': _v(_delivery),
        },
      );
      if (saved == null || !issue) return saved;
      return procurementProvider.act('inventory-purchaseOrder-issue', {
        'id': saved['id'],
      });
    }, done: issue ? 'Issued' : 'Draft saved');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, _campus}.toList();
    final vendors = context.watch<ProcurementProvider>().vendors.where(
      (vendor) => vendor.active || vendor.id == _vendor,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing?.number ?? 'PO · ${widget.request.number}'),
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
              onChanged: _quotationId == null
                  ? (value) => _vendor = value
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _campus,
              decoration: const InputDecoration(labelText: 'Deliver to *'),
              items: [
                for (final value in campuses)
                  DropdownMenuItem(value: value, child: Text('Campus $value')),
              ],
              onChanged: (value) => _campus = value ?? _campus,
            ),
            dateField(context, _expected, 'Expected delivery *'),
            TextFormField(
              controller: _terms,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Terms and conditions',
              ),
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
              onPressed: _busy ? null : () => _save(issue: true),
              child: Text(_busy ? 'Saving…' : 'Save and issue'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(issue: false),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
  }
}
