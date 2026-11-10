import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
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
    if (_from == _to) {
      return showMessage(context, 'Source and destination stores must differ');
    }
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
      done: 'Transfer requested successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = context.watch<StockProvider>().allStores.where(
      (store) => store.active && store.id != _from,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New Stock Transfer')),
      body: IcueCenteredBody(
        maxWidth: 900,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Route Card
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
                            Icons.swap_horiz_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Transfer Route',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StoreDropdown(
                        label: 'Source Store (From)',
                        value: _from,
                        onChanged: (value) => setState(() {
                          _from = value;
                          if (_to == value) _to = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // Re-created when the source changes, so a cleared choice is not shown.
                        key: ValueKey('to-$_from-$_to'),
                        initialValue: _to,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Destination Store (To)',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                        ),
                        items: [
                          for (final store in destination)
                            DropdownMenuItem(
                              value: store.id,
                              child: Text(
                                store.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _to = value),
                        validator: (value) => value == null ? 'Required' : null,
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
                            'Items to Transfer',
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
                        onChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remarks
              IcueTextField(
                controller: _remarks,
                label: 'Remarks / Notes (optional)',
                hintText: 'e.g. Relocating surplus stock for academic event',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),

              IcueButton(
                label: _busy ? 'Submitting…' : 'Request Transfer',
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.arrow_forward_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
