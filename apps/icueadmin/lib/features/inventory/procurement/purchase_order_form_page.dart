import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
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

  final InvPurchaseRequest request;
  final InvQuotation? quotation;
  final InvPurchaseOrder? existing;

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
    final p = context.read<ProcurementProvider>();
    if (p.vendors.isEmpty) p.loadVendors();
    final locked = _quotationId != null;
    OrderLineInput add(String item, String? variant, double q, double price) =>
        OrderLineInput(
          item,
          variant,
          p.itemName(item),
          qty: fmtQty(q),
          price: price == 0 ? '' : fmtQty(price),
          priceLocked: locked,
        );
    final e = widget.existing;
    final quote = widget.quotation;
    if (e != null) {
      for (final l in e.lines) {
        _lines.add(add(l.itemId, l.variantId, l.qty, l.unitPrice));
      }
    } else if (quote != null) {
      for (final l in quote.lines) {
        final left = widget.request.lines
            .where((x) => x.itemId == l.itemId && x.variantId == l.variantId)
            .map((x) => x.qty - x.qtyOrdered);
        final q = left.isEmpty || left.first > l.qty ? l.qty : left.first;
        if (q > 0) _lines.add(add(l.itemId, l.variantId, q, l.unitPrice));
      }
    } else {
      for (final l in widget.request.lines) {
        if (l.qty > l.qtyOrdered) {
          _lines.add(
            add(l.itemId, l.variantId, l.qty - l.qtyOrdered, l.estPrice),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_expected, _terms, _remarks, _discount, _tax, _delivery]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save({required bool issue}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return invSnack(context, 'Nothing left to order');
    setState(() => _busy = true);
    await procSubmit(context, (p) async {
      final saved = await p.act('inv-po-save', {
        'id': ?widget.existing?.id,
        'prId': widget.request.id,
        'quotationId': ?_quotationId,
        'vendorId': _vendor,
        'deliveryCampusId': _campus,
        'expectedDate': _expected.text,
        'terms': _terms.text.trim(),
        'remarks': _remarks.text.trim(),
        'lines': [for (final l in _lines) l.toJson('qtyOrdered')],
        'discount': _v(_discount),
        'tax': _v(_tax),
        'delivery': _v(_delivery),
      });
      if (saved == null || !issue) return saved;
      return p.act('inv-po-issue', {'id': saved['id']});
    }, done: issue ? 'Issued' : 'Draft saved');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campuses, _campus}.toList();
    final vendors = context.watch<ProcurementProvider>().vendors.where(
      (v) => v.active || v.id == _vendor,
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
                for (final v in vendors)
                  DropdownMenuItem(value: v.id, child: Text(v.name)),
              ],
              onChanged: _quotationId == null ? (v) => _vendor = v : null,
              validator: (v) => v == null ? 'Required' : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _campus,
              decoration: const InputDecoration(labelText: 'Deliver to *'),
              items: [
                for (final c in campuses)
                  DropdownMenuItem(value: c, child: Text('Campus $c')),
              ],
              onChanged: (v) => _campus = v ?? _campus,
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
              lines: _lines,
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
