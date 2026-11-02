import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/line_editor.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';

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
      (stockProvider) => stockProvider.act('inventory-receipt-confirm', {
        'storeId': _store,
        'source': _source,
        'reference': _reference.text.trim(),
        'remarks': _remarks.text.trim(),
        'lineItems': [
          for (final lineDraft in _lines)
            lineDraft.toMap(
              quantityKey: 'quantityAccepted',
              batch: true,
              receipt: true,
            ),
        ],
      }, requestId: _requestId),
      done: 'Stock received successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Stock')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Store & Source Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warehouse_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Destination & Source',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StoreDropdown(
                      value: _store,
                      onChanged: (value) => setState(() => _store = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _source,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Source of stock',
                        prefixIcon: Icon(Icons.source_outlined),
                      ),
                      items: [
                        for (final mapEntry in _sources.entries)
                          DropdownMenuItem(
                            value: mapEntry.key,
                            child: Text(
                              mapEntry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _source = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(
                        labelText: 'Reference number / Challan (optional)',
                        hintText: 'e.g. DC-2024-001, OP-STOCK-2024',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Items to Receive',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_lines.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_lines.length} items',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LineEditor(
                      lineItems: _lines,
                      receipt: true,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(
                labelText: 'Remarks / Notes (optional)',
                hintText: 'e.g. Verified by physical count',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_busy ? 'Receiving…' : 'Confirm Receiving'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
