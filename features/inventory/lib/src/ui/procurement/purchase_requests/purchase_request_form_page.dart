import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_line_card.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
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
            quantity: purchaseRequestLine.quantity.toQuantityText(),
            price: purchaseRequestLine.estimatedPrice.toQuantityText(),
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
              : picked.item.defaultPrice!.toQuantityText(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, ?_campus}.toList();
    // A single campus needs no choice.
    final singleCampus = campuses.length == 1;
    if (singleCampus) _campus = campuses.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'New Purchase Request'
              : 'Edit ${widget.existing!.number}',
        ),
      ),
      body: IcueCenteredBody(
        maxWidth: 900,
        child: Form(
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
                          if (!singleCampus) ...[
                            Expanded(
                              child: IcueDropdown<int>(
                                value: _campus,
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
                                label: 'Campus *',
                                icon: Icons.school_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: IcueDropdown<String>(
                              value: _priority,
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
                              label: 'Priority',
                              icon: Icons.flag_outlined,
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
                      IcueTextField(
                        controller: _purpose,
                        validator: requiredText,
                        label: 'Purpose / Justification *',
                        hintText:
                            'e.g. Science lab equipment for term practicals',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 12),
                      IcueDateField(
                        controller: _date,
                        label: 'Required by date *',
                        prefixIcon: const Icon(Icons.event_outlined),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
                        ),
                        validator: requiredText,
                      ),
                      const SizedBox(height: 12),
                      IcueTextField(
                        controller: _remarks,
                        label: 'Remarks / Special instructions (optional)',
                        icon: Icons.notes_rounded,
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
                      IcueButton(
                        label: 'Add Item to Request',
                        onPressed: _addItem,
                        variant: IcueButtonVariant.outline,
                        leadingIcon: Icons.add_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              IcueButton(
                label: _busy ? 'Saving…' : 'Submit for Approval',
                onPressed: _busy ? null : () => _save(submit: true),
                leadingIcon: Icons.send_rounded,
                isLoading: _busy,
              ),
              const SizedBox(height: 10),
              IcueButton(
                label: 'Save as Draft',
                onPressed: _busy ? null : () => _save(submit: false),
                variant: IcueButtonVariant.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
