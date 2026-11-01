import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class _Line {
  _Line(
    this.itemId,
    this.name,
    this.variantId, {
    String quantity = '',
    String price = '',
  }) : quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);

  final String itemId;
  final String name;
  final String? variantId;
  final TextEditingController quantity;
  final TextEditingController price;

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

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
  final _lines = <_Line>[];
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
          _Line(
            purchaseRequestLine.itemId,
            items[purchaseRequestLine.itemId]?.name ??
                purchaseRequestLine.itemId,
            purchaseRequestLine.variantId,
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
                'variantId': ?line.variantId,
                'quantity': double.parse(line.quantity.text.trim()),
                'estimatedPrice': double.tryParse(line.price.text.trim()) ?? 0,
              },
          ],
          'submit': submit,
        },
      ),
      done: submit ? 'Submitted' : 'Draft saved',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addItem() async {
    final picked = await pickItem(context, assets: true);
    if (picked == null || !mounted) return;
    context.read<ProcurementProvider>().items[picked.item.id] = picked.item;
    setState(() {
      _lines.add(
        _Line(
          picked.item.id,
          picked.variant == null
              ? picked.item.name
              : '${picked.item.name} · ${picked.variant!.sku}',
          picked.variant?.id,
          price: picked.item.defaultPrice == null
              ? ''
              : formatQuantity(picked.item.defaultPrice!),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, ?_campus}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'New purchase request'
              : widget.existing!.number,
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _campus,
              decoration: const InputDecoration(labelText: 'Campus *'),
              items: [
                for (final value in campuses)
                  DropdownMenuItem(value: value, child: Text('Campus $value')),
              ],
              onChanged: widget.existing == null
                  ? (value) => _campus = value
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            TextFormField(
              controller: _purpose,
              decoration: const InputDecoration(labelText: 'Purpose *'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _date,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Required by *',
                suffixIcon: Icon(Icons.event_rounded),
              ),
              validator: requiredText,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: DateTime.now(),
                );
                if (date != null) {
                  _date.text = date.toIso8601String().substring(0, 10);
                }
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final value in ['low', 'normal', 'high', 'urgent'])
                  DropdownMenuItem(
                    value: value,
                    child: Text(humanizeStatus(value)),
                  ),
              ],
              onChanged: (value) => _priority = value ?? 'normal',
            ),
            TextFormField(
              controller: _remarks,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 12),
            for (final (n, l) in _lines.indexed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                setState(() => _lines.removeAt(n).dispose()),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: l.quantity,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              validator: (value) {
                                final quantity = double.tryParse(
                                  (value ?? '').trim(),
                                );
                                return quantity == null || quantity <= 0
                                    ? 'Invalid'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: l.price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Est. price',
                              ),
                              validator: optionalNumber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add item'),
                onPressed: _addItem,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _save(submit: true),
              child: Text(_busy ? 'Saving…' : 'Submit for approval'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(submit: false),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
  }
}
