import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_request_line_card.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Create a purchase request, or edit a draft / returned one ([existing]).
class PurchaseRequestFormPage extends StatefulWidget {
  const PurchaseRequestFormPage({super.key, this.existing});

  final InventoryPurchaseRequest? existing;

  @override
  State<PurchaseRequestFormPage> createState() =>
      _PurchaseRequestFormPageState();
}

class _PurchaseRequestFormPageState extends State<PurchaseRequestFormPage> {
  final _form = GlobalKey<FormState>();
  late final _purpose = TextEditingController(text: widget.existing?.purpose);
  late final _remarks = TextEditingController(text: widget.existing?.remarks);
  late final _date = TextEditingController(text: widget.existing?.requiredDate);
  final _lines = <RequestLineDraft>[];
  late int? _campus = widget.existing?.campusId;
  late String _priority = widget.existing?.priority ?? 'normal';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
    final purchaseRequest = widget.existing;
    if (purchaseRequest != null) {
      final items = context.read<ProcurementProvider>().items;
      for (final purchaseRequestLine in purchaseRequest.lineItems) {
        _lines.add(
          RequestLineDraft(
            purchaseRequestLine.itemId,
            items[purchaseRequestLine.itemId]?.name ??
                purchaseRequestLine.itemId,
            quantity: formatQuantity(purchaseRequestLine.quantity),
            price: formatQuantity(purchaseRequestLine.estimatedPrice),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_purpose, _remarks, _date]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Add at least one item');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) => procurementProvider.act(
        'inventory-purchaseRequest-save',
        {
          'id': ?widget.existing?.id,
          'campusId': _campus,
          'requiredDate': _date.text,
          'priority': _priority,
          'purpose': _purpose.text.trim(),
          'remarks': _remarks.text.trim(),
          'lineItems': [
            for (final line in _lines)
              {
                'itemId': line.itemId,
                'quantity': double.parse(line.quantity.text.trim()),
                'estimatedPrice': double.tryParse(line.price.text.trim()) ?? 0,
              },
          ],
          'submit': submit,
        },
      ),
      done: submit ? 'Submitted for approval' : 'Draft saved',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addItem() async {
    final picked = await pickItem(context, assets: true);
    if (picked == null || !mounted) return;
    context.read<ProcurementProvider>().items[picked.item.id] = picked.item;
    setState(() {
      _lines.add(
        RequestLineDraft(
          picked.item.id,
          picked.item.name,
          price: picked.item.defaultPrice == null
              ? ''
              : formatQuantity(picked.item.defaultPrice!),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, ?_campus}.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'New Purchase Request'
              : 'Edit ${widget.existing!.number}',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campus & Priority Card
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
                          Icons.apartment_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Campus & Urgency',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _campus,
                            decoration: const InputDecoration(
                              labelText: 'Campus *',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: [
                              for (final value in campuses)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text('Campus $value'),
                                ),
                            ],
                            onChanged: widget.existing == null
                                ? (value) => _campus = value
                                : null,
                            validator: (value) =>
                                value == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'low',
                                child: Text('Low'),
                              ),
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Normal'),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Text('High'),
                              ),
                              DropdownMenuItem(
                                value: 'urgent',
                                child: Text('Urgent'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value ?? 'normal'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Purpose & Schedule Card
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
                          Icons.description_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Requisition Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _purpose,
                      decoration: const InputDecoration(
                        labelText: 'Purpose / Justification *',
                        hintText:
                            'e.g. Science lab equipment for term practicals',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: requiredText,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _date,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Required by date *',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.event_outlined),
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      validator: requiredText,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                        );
                        if (date != null) {
                          _date.text = date.toIso8601String().substring(0, 10);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarks,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Special instructions (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
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
                          Icons.checklist_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Requested Items',
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
                    for (final (n, l) in _lines.indexed) ...[
                      RequestLineCard(
                        line: l,
                        onRemove: () =>
                            setState(() => _lines.removeAt(n).dispose()),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Item to Request'),
                      onPressed: _addItem,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(submit: true),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Saving…' : 'Submit for Approval'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(submit: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save as Draft'),
            ),
          ],
        ),
      ),
    );
  }
}
