import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Add a quotation to an approved request, or edit a draft ([existing]).
class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({required this.request, this.existing, super.key});

  final InvPurchaseRequest request;
  final InvQuotation? existing;

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
    final p = context.read<ProcurementProvider>();
    if (p.vendors.isEmpty) p.loadVendors();
    final e = widget.existing;
    if (e != null) {
      for (final l in e.lines) {
        _lines.add(
          OrderLineInput(
            l.itemId,
            l.variantId,
            p.itemName(l.itemId),
            qty: fmtQty(l.qty),
            price: fmtQty(l.unitPrice),
          ),
        );
      }
    } else {
      for (final l in widget.request.lines) {
        _lines.add(
          OrderLineInput(
            l.itemId,
            l.variantId,
            p.itemName(l.itemId),
            qty: fmtQty(l.qty),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _ref,
      _valid,
      _days,
      _remarks,
      _discount,
      _tax,
      _delivery,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save({required bool finalize}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return invSnack(context, 'Keep at least one item');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (p) => p.act('inv-quotation-save', {
        'id': ?widget.existing?.id,
        'prId': widget.request.id,
        'vendorId': _vendor,
        'vendorRef': _ref.text.trim(),
        'validUntil': _valid.text,
        'deliveryDays': int.tryParse(_days.text.trim()),
        'lines': [for (final l in _lines) l.toJson('qty')],
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
      (v) => v.active || v.id == _vendor,
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
                for (final v in vendors)
                  DropdownMenuItem(value: v.id, child: Text(v.name)),
              ],
              onChanged: (v) => _vendor = v,
              validator: (v) => v == null ? 'Required' : null,
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
              lines: _lines,
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
