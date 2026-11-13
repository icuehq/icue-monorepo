import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
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
  int _nextSample = 5; // the asset samples come first (see _sampleItems)
  bool _busy = false;

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    for (final controller in [_name, _description, _reorder, _price]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _blank(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  /// Fills the form with the next sample whose name is not loaded yet, using the
  /// first active category and the first unit (debug builds, new items only).
  void _fillSample() {
    final provider = context.read<InventoryProvider>();
    final category = provider.topCategories
        .where((category) => category.active)
        .firstOrNull;
    final unit = provider.units.firstOrNull;
    if (category == null || unit == null) {
      showMessage(context, 'Add a category and a unit first');
      return;
    }
    final taken = {for (final item in provider.items) item.name.toLowerCase()};
    for (var tried = 0; tried < _sampleItems.length; tried++) {
      final sample = _sampleItems[_nextSample++ % _sampleItems.length];
      if (taken.contains(sample.name.toLowerCase())) continue;
      setState(() {
        _name.text = sample.name;
        _description.text = sample.description;
        _reorder.text = '${sample.reorder}';
        _price.text = '${sample.price}';
        _categoryId = category.id;
        _subcategoryId = null;
        _stockUnit = unit.code;
        _tracking = sample.tracking ?? category.suggestedTracking;
      });
      return;
    }
    showMessage(context, 'All sample items already exist');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveItem({
        if (_existingItem != null) 'id': _existingItem.id,
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
    final basic = IcueFormSectionCard(
      title: 'Basic information',
      icon: Icons.inventory_2_outlined,
      children: [
        IcueTextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: requiredText,
          label: 'Item name *',
          icon: Icons.label_outline,
        ),
        IcueDropdown<String>(
          value: _categoryId,
          items: [
            for (final category in tops)
              DropdownMenuItem(value: category.id, child: Text(category.name)),
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
          IcueDropdown<String?>(
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
        IcueTextField(
          controller: _description,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          label: 'Description',
          icon: Icons.notes_outlined,
        ),
      ],
    );
    final stock = IcueFormSectionCard(
      title: 'Stock & tracking',
      icon: Icons.tune_outlined,
      children: [
        IcueDropdown<String>(
          value: _stockUnit,
          items: [
            for (final unit in inventoryProvider.units)
              DropdownMenuItem(value: unit.code, child: Text(unit.name)),
          ],
          validator: (value) => value == null ? 'Required' : null,
          onChanged: (value) => setState(() => _stockUnit = value),
          label: 'Stock unit *',
          icon: Icons.straighten_outlined,
        ),
        IcueDropdown<Tracking>(
          key: ValueKey(_tracking),
          value: _tracking,
          items: [
            for (final tracking in Tracking.values)
              DropdownMenuItem(value: tracking, child: Text(tracking.label)),
          ],
          onChanged: (tracking) => _tracking = tracking ?? _tracking,
          label: 'Tracking method *',
          icon: Icons.track_changes_outlined,
        ),
      ],
    );
    final reorder = IcueFormSectionCard(
      title: 'Reorder & pricing',
      icon: Icons.payments_outlined,
      children: [
        IcueTextField(
          controller: _reorder,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [decimalInputFormatter],
          textInputAction: TextInputAction.next,
          validator: optionalNumber,
          label: 'Reorder level',
          icon: Icons.refresh_outlined,
          helperText: 'Alert threshold when available stock is low',
        ),
        IcueTextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [decimalInputFormatter],
          textInputAction: TextInputAction.done,
          validator: optionalNumber,
          label: 'Default purchase price',
          icon: Icons.payments_outlined,
          helperText: 'Estimated unit cost for purchase requests',
        ),
      ],
    );
    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (kDebugMode && !editing) ...[
          IcueButton(
            label: 'Fill sample',
            onPressed: _busy ? null : _fillSample,
            variant: IcueButtonVariant.ghost,
            leadingIcon: Icons.auto_fix_high_rounded,
          ),
          const Spacer(),
        ],
        IcueButton(
          label: 'Cancel',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          variant: IcueButtonVariant.outline,
        ),
        const SizedBox(width: 12),
        IcueButton(
          label: _busy ? 'Saving…' : (editing ? 'Update item' : 'Save item'),
          onPressed: _busy ? null : _save,
          leadingIcon: Icons.check_circle_outline,
          isLoading: _busy,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'Add item')),
      body: IcueCenteredBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.all(context.isWide ? 24 : 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Two columns from the wide breakpoint, one stacked column below it.
              if (context.isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: basic),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(children: [stock, reorder]),
                    ),
                  ],
                )
              else ...[
                basic,
                stock,
                reorder,
              ],
              const SizedBox(height: 8),
              actions,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

const _sampleItems =
    <
      ({
        String name,
        String description,
        int reorder,
        int price,
        Tracking? tracking,
      })
    >[
      (
        name: 'A4 Copier Paper (500 sheets)',
        description: '75 GSM white copier paper ream.',
        reorder: 20,
        price: 260,
        tracking: null,
      ),
      (
        name: 'Blue Ball Pen',
        description: '0.7 mm ball point pen.',
        reorder: 100,
        price: 8,
        tracking: null,
      ),
      (
        name: 'Whiteboard Marker',
        description: 'Assorted colours, bullet tip.',
        reorder: 50,
        price: 25,
        tracking: null,
      ),
      (
        name: 'Floor Cleaner (5 L)',
        description: 'Disinfectant floor cleaning liquid.',
        reorder: 10,
        price: 350,
        tracking: null,
      ),
      (
        name: 'Basketball (Size 7)',
        description: 'Rubber outdoor basketball.',
        reorder: 5,
        price: 900,
        tracking: null,
      ),
      (
        name: 'Dell Latitude Laptop',
        description: 'Teacher laptop, tracked per unit.',
        reorder: 0,
        price: 48500,
        tracking: Tracking.asset,
      ),
      (
        name: 'Epson Classroom Projector',
        description: 'Ceiling or table projector, tracked per unit.',
        reorder: 0,
        price: 32900,
        tracking: Tracking.asset,
      ),
      (
        name: 'Olympus Lab Microscope',
        description: 'Compound microscope, tracked per unit.',
        reorder: 0,
        price: 27500,
        tracking: Tracking.asset,
      ),
    ];
