import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Records a vendor invoice against a purchase order (FRS 10.18); payment is Finance's, not made here.
class InvoiceFormSheet extends StatefulWidget {
  const InvoiceFormSheet({required this.order, super.key});

  final InvPurchaseOrder order;

  static Future<void> show(BuildContext context, InvPurchaseOrder order) =>
      showInvSheet(context, () => InvoiceFormSheet(order: order));

  @override
  State<InvoiceFormSheet> createState() => _InvoiceFormSheetState();
}

class _InvoiceFormSheetState extends State<InvoiceFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _no = TextEditingController();
  final _date = TextEditingController();
  final _due = TextEditingController();
  late final _subtotal = TextEditingController(
    text: widget.order.subtotal.toStringAsFixed(2),
  );
  late final _tax = TextEditingController(
    text: widget.order.tax.toStringAsFixed(2),
  );
  late final _discount = TextEditingController(
    text: widget.order.discount.toStringAsFixed(2),
  );
  final _receipts = <String>{};
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadReceipts(
        context.read<InventoryProvider>().access,
        widget.order.id,
      );
    });
  }

  @override
  void dispose() {
    for (final c in [_no, _date, _due, _subtotal, _tax, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await procSubmit(
      context,
      (p) => p.act('inv-invoice-save', {
        'poId': widget.order.id,
        'invoiceNo': _no.text.trim(),
        'invoiceDate': _date.text,
        'dueDate': _due.text,
        'subtotal': _v(_subtotal),
        'tax': _v(_tax),
        'discount': _v(_discount),
        'receiptIds': _receipts.toList(),
      }, requestId: _requestId),
      done: 'Invoice recorded',
    );
    if (mounted) setState(() => _busy = false);
  }

  Widget _amount(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final n = double.tryParse((v ?? '').trim());
      return n == null || n < 0 ? 'Invalid' : null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final grns = context.watch<ProcurementProvider>().receipts;
    final today = DateTime.now();
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invoice for ${widget.order.number}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextFormField(
            controller: _no,
            decoration: const InputDecoration(labelText: 'Invoice number *'),
            validator: requiredText,
          ),
          dateField(
            context,
            _date,
            'Invoice date',
            first: today.subtract(const Duration(days: 365)),
          ),
          dateField(
            context,
            _due,
            'Due date',
            first: today.subtract(const Duration(days: 365)),
          ),
          _amount(_subtotal, 'Subtotal'),
          _amount(_tax, 'Tax'),
          _amount(_discount, 'Discount'),
          if (grns.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Receiving references'),
            Wrap(
              spacing: 8,
              children: [
                for (final g in grns)
                  FilterChip(
                    label: Text(g.number),
                    selected: _receipts.contains(g.id),
                    onSelected: (on) => setState(
                      () => on ? _receipts.add(g.id) : _receipts.remove(g.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Record invoice'),
          ),
        ],
      ),
    );
  }
}
