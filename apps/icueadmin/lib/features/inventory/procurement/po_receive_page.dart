import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class _Draft {
  _Draft(this.line);

  final OrderLine line;
  final accepted = TextEditingController();
  final rejected = TextEditingController();
  final condition = TextEditingController();
  final batchNo = TextEditingController();
  final expiry = TextEditingController();

  double get acceptedValue => double.tryParse(accepted.text.trim()) ?? 0;
  double get rejectedValue => double.tryParse(rejected.text.trim()) ?? 0;
  bool get touched => acceptedValue + rejectedValue > 0;

  void dispose() {
    for (final c in [accepted, rejected, condition, batchNo, expiry]) {
      c.dispose();
    }
  }

  Map<String, Object?> toJson() {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'itemId': line.itemId,
      'variantId': ?line.variantId,
      'qtyAccepted': acceptedValue,
      'qtyRejected': rejectedValue,
      'condition': text(condition),
      'batchNo': text(batchNo),
      'expiryDate': text(expiry),
    };
  }
}

/// One delivery against a purchase order: accepted and rejected quantities per line (FRS 10.17).
class PoReceivePage extends StatefulWidget {
  const PoReceivePage({required this.order, super.key});

  final InvPurchaseOrder order;

  @override
  State<PoReceivePage> createState() => _PoReceivePageState();
}

class _PoReceivePageState extends State<PoReceivePage> {
  final _form = GlobalKey<FormState>();
  final _deliveryRef = TextEditingController();
  final _remarks = TextEditingController();
  final _requestId = newRequestId();
  late final _drafts = [
    for (final l in widget.order.lines.where((l) => l.due > 0)) _Draft(l),
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
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final lines = _drafts.where((d) => d.touched).toList();
    if (lines.isEmpty) return invSnack(context, 'Enter a received quantity');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (p) => p.act('inv-po-receive', {
        'poId': widget.order.id,
        'storeId': _store,
        'deliveryRef': _deliveryRef.text.trim(),
        'remarks': _remarks.text.trim(),
        'lines': [for (final d in lines) d.toJson()],
      }, requestId: _requestId),
      done: 'Received',
    );
    if (mounted) setState(() => _busy = false);
  }

  String? _qty(String? v, _Draft d) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || n < 0) return 'Invalid';
    return d.acceptedValue + d.rejectedValue > d.line.due
        ? 'Only ${fmtQty(d.line.due)} due'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProcurementProvider>();
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Receive ${o.number}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${p.vendorName(o.vendorId)} · due ${o.expectedDate}'),
            const SizedBox(height: 12),
            StoreDropdown(
              value: _store,
              campusId: o.deliveryCampusId,
              onChanged: (v) => setState(() => _store = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryRef,
              decoration: const InputDecoration(
                labelText: 'Delivery note / challan no. (optional)',
              ),
            ),
            const SizedBox(height: 12),
            for (final d in _drafts) _line(context, p, d),
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

  Widget _line(BuildContext context, ProcurementProvider p, _Draft d) {
    final batch = p.items[d.line.itemId]?.tracking == Tracking.batch;
    const num = TextInputType.numberWithOptions(decimal: true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.itemName(d.line.itemId),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Ordered ${fmtQty(d.line.qty)} · still due ${fmtQty(d.line.due)}',
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.accepted,
                    keyboardType: num,
                    decoration: const InputDecoration(labelText: 'Accepted'),
                    validator: (v) => _qty(v, d),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: d.rejected,
                    keyboardType: num,
                    decoration: const InputDecoration(labelText: 'Rejected'),
                    validator: (v) => _qty(v, d),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: d.condition,
              decoration: const InputDecoration(
                labelText: 'Condition (optional)',
              ),
            ),
            if (batch)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: d.batchNo,
                      decoration: const InputDecoration(labelText: 'Batch no.'),
                      validator: (v) => d.touched && (v ?? '').trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _expiry(context, d.expiry)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _expiry(BuildContext context, TextEditingController c) =>
      TextFormField(
        controller: c,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Expiry',
          suffixIcon: Icon(Icons.event_rounded),
        ),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: DateTime.now(),
          );
          if (d != null) c.text = d.toIso8601String().substring(0, 10);
        },
      );
}
