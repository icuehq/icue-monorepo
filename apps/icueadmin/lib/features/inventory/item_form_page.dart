import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/purchase_units_editor.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key, this.item});

  final InventoryItem? item;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final InventoryItem? _existingItem = widget.item;
  late final _code = TextEditingController(text: _existingItem?.code);
  late final _name = TextEditingController(text: _existingItem?.name);
  late final _description = TextEditingController(
    text: _existingItem?.description,
  );
  late final _attrs = TextEditingController(
    text: _existingItem?.variantAttrs.join(', '),
  );
  late final _min = TextEditingController(text: _num(_existingItem?.minLevel));
  late final _reorder = TextEditingController(
    text: _num(_existingItem?.reorderLevel),
  );
  late final _price = TextEditingController(
    text: _num(_existingItem?.defaultPrice),
  );
  late final _location = TextEditingController(
    text: _existingItem?.defaultLocation,
  );
  late String? _categoryId = _existingItem?.categoryId;
  late String? _subcategoryId = _existingItem?.subcategoryId;
  late String? _stockUnit = _existingItem?.stockUnit;
  late Tracking _tracking = _existingItem?.tracking ?? Tracking.quantity;
  late List<PurchaseUnit> _purchaseUnits = _existingItem?.purchaseUnits ?? [];
  bool _busy = false;

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _description,
      _attrs,
      _min,
      _reorder,
      _price,
      _location,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _blank(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveItem({
        if (_existingItem != null)
          'id': _existingItem.id
        else
          'code': _code.text.trim(),
        'name': _name.text.trim(),
        'categoryId': _categoryId,
        'subcategoryId': _subcategoryId,
        'description': _blank(_description),
        'stockUnit': _stockUnit,
        'purchaseUnits': [
          for (final purchaseUnit in _purchaseUnits) purchaseUnit.toMap(),
        ],
        'tracking': _tracking.name,
        'variantAttrs': [
          for (final value in _attrs.text.split(','))
            if (value.trim().isNotEmpty) value.trim(),
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
    final inventoryProvider = context.watch<InventoryProvider>();
    final editing = _existingItem != null;
    final tops = [
      for (final category in inventoryProvider.topCategories)
        if (category.active || category.id == _existingItem?.categoryId)
          category,
    ];
    final subs = [
      for (final category in inventoryProvider.categories)
        if (category.parentId == _categoryId &&
            (category.active || category.id == _existingItem?.subcategoryId))
          category,
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
                for (final category in tops)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (value) => setState(() {
                _categoryId = value;
                _subcategoryId = null;
                final suggested = inventoryProvider
                    .category(value)
                    ?.suggestedTracking;
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
                  for (final category in subs)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => _subcategoryId = value,
              ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _stockUnit,
              decoration: const InputDecoration(labelText: 'Stock unit *'),
              items: [
                for (final unit in inventoryProvider.units)
                  DropdownMenuItem(
                    value: unit.code,
                    child: Text('${unit.name} (${unit.code})'),
                  ),
              ],
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (value) => setState(() => _stockUnit = value),
            ),
            DropdownButtonFormField<Tracking>(
              key: ValueKey(_tracking),
              initialValue: _tracking,
              decoration: const InputDecoration(labelText: 'Tracking method *'),
              items: [
                for (final tracking in Tracking.values)
                  DropdownMenuItem(
                    value: tracking,
                    child: Text(tracking.label),
                  ),
              ],
              onChanged: (tracking) => _tracking = tracking ?? _tracking,
            ),
            const SizedBox(height: 8),
            PurchaseUnitsEditor(
              units: inventoryProvider.units,
              stockUnit: _stockUnit,
              initial: _purchaseUnits,
              onChanged: (purchaseUnits) => _purchaseUnits = purchaseUnits,
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
