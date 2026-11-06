import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final InventoryItem? _existingItem = widget.item;
  late final _code = TextEditingController(text: _existingItem?.code);
  late final _name = TextEditingController(text: _existingItem?.name);
  late final _description = TextEditingController(
    text: _existingItem?.description,
  );
  late final _reorder = TextEditingController(
    text: _num(_existingItem?.reorderLevel),
  );
  late final _price = TextEditingController(
    text: _num(_existingItem?.defaultPrice),
  );
  late String? _categoryId = _existingItem?.categoryId;
  late String? _subcategoryId = _existingItem?.subcategoryId;
  late String? _stockUnit = _existingItem?.stockUnit;
  late Tracking _tracking = _existingItem?.tracking ?? Tracking.quantity;
  bool _busy = false;

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    for (final controller in [_code, _name, _description, _reorder, _price]) {
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
        'tracking': _tracking.name,
        'reorderLevel': _d(_reorder),
        'defaultPrice': _d(_price),
      }),
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
        if (_categoryId != null &&
            category.parentId == _categoryId &&
            (category.active || category.id == _existingItem?.subcategoryId))
          category,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'Add item')),
      body: CenteredBody(
        maxWidth: Breakpoints.formMaxWidth,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              FormSectionCard(
                title: 'Basic information',
                icon: Icons.inventory_2_outlined,
                children: [
                  TextFormField(
                    controller: _code,
                    enabled: !editing,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9._\-]'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Item code / SKU *',
                      prefixIcon: const Icon(
                        Icons.qr_code_2_outlined,
                        size: 20,
                      ),
                      helperText: !editing
                          ? 'Unique identifier, e.g. PAP-A4-01'
                          : null,
                    ),
                    validator: requiredText,
                  ),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Item name *',
                      prefixIcon: Icon(Icons.label_outline, size: 20),
                    ),
                    validator: requiredText,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                    ),
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
                      decoration: const InputDecoration(
                        labelText: 'Subcategory',
                        prefixIcon: Icon(
                          Icons.subdirectory_arrow_right_outlined,
                          size: 20,
                        ),
                      ),
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
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined, size: 20),
                    ),
                  ),
                ],
              ),
              FormSectionCard(
                title: 'Stock & tracking',
                icon: Icons.tune_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _stockUnit,
                    decoration: const InputDecoration(
                      labelText: 'Stock unit *',
                      prefixIcon: Icon(Icons.straighten_outlined, size: 20),
                    ),
                    items: [
                      for (final unit in inventoryProvider.units)
                        DropdownMenuItem(
                          value: unit.code,
                          child: Text(unit.name),
                        ),
                    ],
                    validator: (value) => value == null ? 'Required' : null,
                    onChanged: (value) => setState(() => _stockUnit = value),
                  ),
                  DropdownButtonFormField<Tracking>(
                    key: ValueKey(_tracking),
                    initialValue: _tracking,
                    decoration: const InputDecoration(
                      labelText: 'Tracking method *',
                      prefixIcon: Icon(Icons.track_changes_outlined, size: 20),
                    ),
                    items: [
                      for (final tracking in Tracking.values)
                        DropdownMenuItem(
                          value: tracking,
                          child: Text(tracking.label),
                        ),
                    ],
                    onChanged: (tracking) => _tracking = tracking ?? _tracking,
                  ),
                ],
              ),
              FormSectionCard(
                title: 'Reorder & pricing',
                icon: Icons.payments_outlined,
                children: [
                  TextFormField(
                    controller: _reorder,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Reorder level',
                      prefixIcon: Icon(Icons.refresh_outlined, size: 20),
                      helperText: 'Alert threshold when available stock is low',
                    ),
                    validator: optionalNumber,
                  ),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Default purchase price',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                      helperText: 'Estimated unit cost for purchase requests',
                    ),
                    validator: optionalNumber,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _busy ? 'Saving…' : (editing ? 'Update item' : 'Save item'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
