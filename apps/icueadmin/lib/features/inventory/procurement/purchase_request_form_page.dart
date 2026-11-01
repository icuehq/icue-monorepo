import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class _Line {
  _Line(
    this.itemId,
    this.name,
    this.variantId, {
    String qty = '',
    String price = '',
  }) : qty = TextEditingController(text: qty),
       price = TextEditingController(text: price);

  final String itemId;
  final String name;
  final String? variantId;
  final TextEditingController qty;
  final TextEditingController price;

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

/// Create a purchase request, or edit a draft / returned one ([existing]).
class PurchaseRequestFormPage extends StatefulWidget {
  const PurchaseRequestFormPage({super.key, this.existing});

  final InvPurchaseRequest? existing;

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
    final r = widget.existing;
    if (r != null) {
      final items = context.read<ProcurementProvider>().items;
      for (final l in r.lines) {
        _lines.add(
          _Line(
            l.itemId,
            items[l.itemId]?.name ?? l.itemId,
            l.variantId,
            qty: fmtQty(l.qty),
            price: fmtQty(l.estPrice),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_purpose, _remarks, _date]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return invSnack(context, 'Add at least one item');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (p) => p.act('inv-pr-save', {
        'id': ?widget.existing?.id,
        'campusId': _campus,
        'requiredDate': _date.text,
        'priority': _priority,
        'purpose': _purpose.text.trim(),
        'remarks': _remarks.text.trim(),
        'lines': [
          for (final l in _lines)
            {
              'itemId': l.itemId,
              'variantId': ?l.variantId,
              'qty': double.parse(l.qty.text.trim()),
              'estPrice': double.tryParse(l.price.text.trim()) ?? 0,
            },
        ],
        'submit': submit,
      }),
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
              : fmtQty(picked.item.defaultPrice!),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campuses, ?_campus}.toList();
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
                for (final c in campuses)
                  DropdownMenuItem(value: c, child: Text('Campus $c')),
              ],
              onChanged: widget.existing == null ? (v) => _campus = v : null,
              validator: (v) => v == null ? 'Required' : null,
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
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: DateTime.now(),
                );
                if (d != null) {
                  _date.text = d.toIso8601String().substring(0, 10);
                }
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final s in ['low', 'normal', 'high', 'urgent'])
                  DropdownMenuItem(value: s, child: Text(statusLabel(s))),
              ],
              onChanged: (v) => _priority = v ?? 'normal',
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
                              controller: l.qty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              validator: (v) {
                                final q = double.tryParse((v ?? '').trim());
                                return q == null || q <= 0 ? 'Invalid' : null;
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
