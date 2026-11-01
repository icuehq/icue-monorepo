import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/purchase_units_editor.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key, this.item});

  final InvItem? item;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final InvItem? _i = widget.item;
  late final _code = TextEditingController(text: _i?.code);
  late final _name = TextEditingController(text: _i?.name);
  late final _desc = TextEditingController(text: _i?.description);
  late final _attrs = TextEditingController(text: _i?.variantAttrs.join(', '));
  late final _min = TextEditingController(text: _num(_i?.minLevel));
  late final _reorder = TextEditingController(text: _num(_i?.reorderLevel));
  late final _price = TextEditingController(text: _num(_i?.defaultPrice));
  late final _location = TextEditingController(text: _i?.defaultLocation);
  late String? _categoryId = _i?.categoryId;
  late String? _subcategoryId = _i?.subcategoryId;
  late String? _stockUnit = _i?.stockUnit;
  late Tracking _tracking = _i?.tracking ?? Tracking.qty;
  late List<PurchaseUnit> _purchaseUnits = _i?.purchaseUnits ?? [];
  bool _busy = false;

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _desc,
      _attrs,
      _min,
      _reorder,
      _price,
      _location,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim());

  String? _blank(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await invSubmit(
      context,
      () => context.read<InventoryProvider>().saveItem({
        if (_i != null) 'id': _i.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'categoryId': _categoryId,
        'subcategoryId': _subcategoryId,
        'description': _blank(_desc),
        'stockUnit': _stockUnit,
        'purchaseUnits': [for (final p in _purchaseUnits) p.toMap()],
        'tracking': _tracking.name,
        'variantAttrs': [
          for (final a in _attrs.text.split(','))
            if (a.trim().isNotEmpty) a.trim(),
        ],
        'minLevel': _d(_min),
        'reorderLevel': _d(_reorder),
        'defaultPrice': _d(_price),
        'defaultLocation': _blank(_location),
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();
    final editing = _i != null;
    final tops = [
      for (final c in p.topCategories)
        if (c.active || c.id == _i?.categoryId) c,
    ];
    final subs = [
      for (final c in p.categories)
        if (c.parentId == _categoryId &&
            (c.active || c.id == _i?.subcategoryId))
          c,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'Add item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              enabled: !editing,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Item code / SKU *'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Item name *'),
              validator: requiredText,
            ),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: [
                for (final c in tops)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              validator: (v) => v == null ? 'Required' : null,
              onChanged: (v) => setState(() {
                _categoryId = v;
                _subcategoryId = null;
                final suggested = p.category(v)?.suggestedTracking;
                if (!editing && suggested != null) _tracking = suggested;
              }),
            ),
            if (subs.isNotEmpty)
              DropdownButtonFormField<String?>(
                key: ValueKey(_categoryId),
                initialValue: _subcategoryId,
                decoration: const InputDecoration(labelText: 'Subcategory'),
                items: [
                  const DropdownMenuItem(child: Text('None')),
                  for (final c in subs)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => _subcategoryId = v,
              ),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _stockUnit,
              decoration: const InputDecoration(labelText: 'Stock unit *'),
              items: [
                for (final u in p.units)
                  DropdownMenuItem(
                    value: u.code,
                    child: Text('${u.name} (${u.code})'),
                  ),
              ],
              validator: (v) => v == null ? 'Required' : null,
              onChanged: (v) => setState(() => _stockUnit = v),
            ),
            DropdownButtonFormField<Tracking>(
              key: ValueKey(_tracking),
              initialValue: _tracking,
              decoration: const InputDecoration(labelText: 'Tracking method *'),
              items: [
                for (final t in Tracking.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => _tracking = v ?? _tracking,
            ),
            const SizedBox(height: 8),
            PurchaseUnitsEditor(
              units: p.units,
              stockUnit: _stockUnit,
              initial: _purchaseUnits,
              onChanged: (v) => _purchaseUnits = v,
            ),
            TextFormField(
              controller: _attrs,
              decoration: const InputDecoration(
                labelText: 'Variant attributes',
                helperText: 'Comma-separated, e.g. size, color',
              ),
            ),
            TextFormField(
              controller: _min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum stock level',
              ),
              validator: optionalNumber,
            ),
            TextFormField(
              controller: _reorder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reorder level'),
              validator: optionalNumber,
            ),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default purchase price',
              ),
              validator: optionalNumber,
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Default storage location',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
