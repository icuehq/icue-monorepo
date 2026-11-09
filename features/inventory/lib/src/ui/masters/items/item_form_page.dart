import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
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
                  AppTextField(
                    controller: _code,
                    enabled: !editing,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9._\-]'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    validator: requiredText,
                    label: 'Item code / SKU *',
                    icon: Icons.qr_code_2_outlined,
                    helperText: !editing
                        ? 'Unique identifier, e.g. PAP-A4-01'
                        : null,
                  ),
                  AppTextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: requiredText,
                    label: 'Item name *',
                    icon: Icons.label_outline,
                  ),
                  AppDropdown<String>(
                    value: _categoryId,
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
                    label: 'Category *',
                    icon: Icons.category_outlined,
                  ),
                  if (subs.isNotEmpty)
                    AppDropdown<String?>(
                      key: ValueKey(_categoryId),
                      value: _subcategoryId,
                      items: [
                        const DropdownMenuItem(child: Text('None')),
                        for (final category in subs)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) => _subcategoryId = value,
                      label: 'Subcategory',
                      icon: Icons.subdirectory_arrow_right_outlined,
                    ),
                  AppTextField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    label: 'Description',
                    icon: Icons.notes_outlined,
                  ),
                ],
              ),
              FormSectionCard(
                title: 'Stock & tracking',
                icon: Icons.tune_outlined,
                children: [
                  AppDropdown<String>(
                    value: _stockUnit,
                    items: [
                      for (final unit in inventoryProvider.units)
                        DropdownMenuItem(
                          value: unit.code,
                          child: Text(unit.name),
                        ),
                    ],
                    validator: (value) => value == null ? 'Required' : null,
                    onChanged: (value) => setState(() => _stockUnit = value),
                    label: 'Stock unit *',
                    icon: Icons.straighten_outlined,
                  ),
                  AppDropdown<Tracking>(
                    key: ValueKey(_tracking),
                    value: _tracking,
                    items: [
                      for (final tracking in Tracking.values)
                        DropdownMenuItem(
                          value: tracking,
                          child: Text(tracking.label),
                        ),
                    ],
                    onChanged: (tracking) => _tracking = tracking ?? _tracking,
                    label: 'Tracking method *',
                    icon: Icons.track_changes_outlined,
                  ),
                ],
              ),
              FormSectionCard(
                title: 'Reorder & pricing',
                icon: Icons.payments_outlined,
                children: [
                  AppTextField(
                    controller: _reorder,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    textInputAction: TextInputAction.next,
                    validator: optionalNumber,
                    label: 'Reorder level',
                    icon: Icons.refresh_outlined,
                    helperText: 'Alert threshold when available stock is low',
                  ),
                  AppTextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    textInputAction: TextInputAction.done,
                    validator: optionalNumber,
                    label: 'Default purchase price',
                    icon: Icons.payments_outlined,
                    helperText: 'Estimated unit cost for purchase requests',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: AppButton(
                  label: _busy
                      ? 'Saving…'
                      : (editing ? 'Update item' : 'Save item'),
                  onPressed: _busy ? null : _save,
                  leadingIcon: Icons.check_circle_outline,
                  isLoading: _busy,
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
