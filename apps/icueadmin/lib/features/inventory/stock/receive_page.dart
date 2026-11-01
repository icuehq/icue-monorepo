import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/line_editor.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';

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
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return invSnack(context, 'Add at least one item');
    setState(() => _busy = true);
    await stockSubmit(
      context,
      (p) => p.act('inv-receipt-confirm', {
        'storeId': _store,
        'source': _source,
        'reference': _reference.text.trim(),
        'remarks': _remarks.text.trim(),
        'lines': [
          for (final l in _lines)
            l.toMap(qtyKey: 'qtyAccepted', batch: true, receipt: true),
        ],
      }, requestId: _requestId),
      done: 'Received',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receive stock')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoreDropdown(
            value: _store,
            onChanged: (v) => setState(() => _store = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _source,
            decoration: const InputDecoration(labelText: 'Source'),
            items: [
              for (final e in _sources.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _source = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
            ),
          ),
          const SizedBox(height: 12),
          LineEditor(
            lines: _lines,
            receipt: true,
            onChanged: () => setState(() {}),
          ),
          TextFormField(
            controller: _remarks,
            decoration: const InputDecoration(labelText: 'Remarks (optional)'),
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
