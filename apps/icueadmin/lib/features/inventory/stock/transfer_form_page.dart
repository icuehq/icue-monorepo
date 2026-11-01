import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/line_editor.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class TransferFormPage extends StatefulWidget {
  const TransferFormPage({super.key});

  @override
  State<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends State<TransferFormPage> {
  final _form = GlobalKey<FormState>();
  final _remarks = TextEditingController();
  final _lines = <LineDraft>[];
  final _requestId = newRequestId();
  String? _from;
  String? _to;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<StockProvider>().loadAllStores(),
    );
  }

  @override
  void dispose() {
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
      (stockProvider) => stockProvider.act('inventory-transfer-request', {
        'fromStoreId': _from,
        'toStoreId': _to,
        'remarks': _remarks.text.trim(),
        'lineItems': [for (final lineDraft in _lines) lineDraft.toMap()],
      }, requestId: _requestId),
      done: 'Transfer requested',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final destination = context.watch<StockProvider>().allStores.where(
      (store) => store.active && store.id != _from,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('New transfer')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StoreDropdown(
              label: 'From store',
              value: _from,
              onChanged: (value) => setState(() => _from = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'To store'),
              items: [
                for (final store in destination)
                  DropdownMenuItem(
                    value: store.id,
                    child: Text(
                      '${store.name} (${store.code}) · Campus ${store.campusId}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _to = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            LineEditor(lineItems: _lines, onChanged: () => setState(() {})),
            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Request transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
