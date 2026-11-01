import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/line_editor.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';

class IssueRequestFormPage extends StatefulWidget {
  const IssueRequestFormPage({super.key});

  @override
  State<IssueRequestFormPage> createState() => _IssueRequestFormPageState();
}

class _IssueRequestFormPageState extends State<IssueRequestFormPage> {
  final _form = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _destination = TextEditingController();
  final _lines = <LineDraft>[];
  final _requestId = newRequestId();
  String? _store;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    _purpose.dispose();
    _destination.dispose();
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
      (stockProvider) => stockProvider.act('inventory-issueRequest-submit', {
        'storeId': _store,
        'purpose': _purpose.text.trim(),
        'destination': _destination.text.trim(),
        'lineItems': [for (final lineDraft in _lines) lineDraft.toMap()],
      }, requestId: _requestId),
      done: 'Request sent',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New issue request')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoreDropdown(
            label: 'Issue from store',
            value: _store,
            onChanged: (value) => setState(() => _store = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _destination,
            decoration: const InputDecoration(
              labelText: 'Destination (optional)',
            ),
          ),
          const SizedBox(height: 12),
          LineEditor(lineItems: _lines, onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Sending…' : 'Submit request'),
          ),
        ],
      ),
    ),
  );
}
