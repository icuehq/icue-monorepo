import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_item_field.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Registers one asset, or several identical units at once (FRS 10.19).
class AssetFormPage extends StatefulWidget {
  const AssetFormPage({super.key});

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  static const _maxQuantity = 50;
  static final _pricePattern = RegExp(r'^\d{1,9}(\.\d{1,2})?$');

  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _purchased = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _warrantyEnd = TextEditingController();
  InventoryItem? _item;
  String? _store;
  var _condition = 'new';
  var _busy = false;
  var _submitted = false;
  var _nextSample = 0;

  int get _units => int.tryParse(_quantity.text.trim()) ?? 1;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serial,
      _quantity,
      _make,
      _model,
      _price,
      _location,
      _purchased,
      _warrantyStart,
      _warrantyEnd,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickItem(context, assetsOnly: true);
    if (picked == null || !mounted) return;
    if (picked.item.tracking != Tracking.asset) {
      showMessage(
        context,
        '${picked.item.name} is not tracked as an individual asset',
      );
      return;
    }
    setState(() {
      _item = picked.item;
      if (_name.text.isEmpty) _name.text = picked.item.name;
    });
  }

  String? _opt(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  String? _maxLength(String? value, int max, String what) =>
      (value ?? '').trim().length > max
      ? '$what must be $max characters or fewer'
      : null;

  String? _validateQuantity(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 1 || number > _maxQuantity) {
      return 'Enter a whole number from 1 to $_maxQuantity';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_pricePattern.hasMatch(text)) {
      return 'Enter an amount with up to 2 decimals';
    }
    return null;
  }

  String? _validateWarrantyStart(String? value) =>
      _warrantyEnd.text.isNotEmpty && (value ?? '').isEmpty
      ? 'Add the warranty start date'
      : null;

  String? _validateWarrantyEnd(String? value) {
    final end = value ?? '';
    final start = _warrantyStart.text;
    if (start.isNotEmpty && end.isEmpty) return 'Add the warranty end date';
    // `yyyy-MM-dd` strings sort in date order.
    if (start.isNotEmpty && end.compareTo(start) < 0) {
      return 'Must be on or after the start date';
    }
    return null;
  }

  /// Fills the form with the next sample (debug builds only); picks the first asset-tracked item when none is chosen.
  Future<void> _fillSample() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (_item == null) {
      await inventoryProvider.loadItems(search: '', clearCategory: true);
      if (!mounted) return;
    }
    final assetItems = inventoryProvider.items.where(
      (item) => item.tracking == Tracking.asset,
    );
    final sample = _sampleAssets[_nextSample++ % _sampleAssets.length];
    final stores = inventoryProvider.stores.where((store) => store.active);
    final today = DateTime.now();
    setState(() {
      _item ??= assetItems.isEmpty ? null : assetItems.first;
      _name.text = sample.name;
      _quantity.text = '1';
      _serial.text = sample.serial;
      _make.text = sample.make;
      _model.text = sample.model;
      _price.text = sample.price;
      _location.text = sample.location;
      _condition = 'new';
      _store ??= stores.isEmpty ? null : stores.first.id;
      _purchased.text = today.subtract(const Duration(days: 30)).toApiDate();
      _warrantyStart.text = _purchased.text;
      _warrantyEnd.text = today.add(const Duration(days: 700)).toApiDate();
    });
    if (_item == null) {
      showMessage(context, 'No asset-tracked item exists yet; pick one');
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    final units = _units;
    setState(() => _busy = true);
    await assetSubmit(
      context,
      (assetsProvider) => assetsProvider.act('inventory-asset-register', {
        'itemId': _item!.id,
        'storeId': _store,
        'quantity': units,
        'name': _opt(_name),
        'serialNumber': units > 1 ? null : _opt(_serial),
        'make': _opt(_make),
        'model': _opt(_model),
        'purchaseDate': _opt(_purchased),
        'price': double.tryParse(_price.text.trim()),
        'warrantyStart': _opt(_warrantyStart),
        'warrantyEnd': _opt(_warrantyEnd),
        'condition': _condition,
        'location': _opt(_location),
      }, requestId: _requestId),
      done: units > 1 ? '$units assets registered' : 'Asset registered',
    );
    if (mounted) setState(() => _busy = false);
  }

  /// Two fields side by side when there is room, stacked on phones.
  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(children: [first, const SizedBox(height: 14), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 3650));
    final future = now.add(const Duration(days: 3650));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register asset'),
        actions: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _fillSample,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Fill sample'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IcueFormSectionCard(
              title: 'Asset',
              icon: Icons.inventory_2_outlined,
              children: [
                AssetItemField(item: _item, onPick: _pick),
                IcueTextField(
                  controller: _name,
                  label: 'Asset name',
                  helperText: 'Defaults to the item name',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _maxLength(value, 100, 'Name'),
                ),
                _pair(
                  StoreDropdown(
                    key: ValueKey(_store),
                    value: _store,
                    onChanged: (value) => setState(() => _store = value),
                  ),
                  IcueTextField(
                    controller: _quantity,
                    label: 'Quantity',
                    helperText: 'Identical units, up to $_maxQuantity',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateQuantity,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            IcueFormSectionCard(
              title: 'Identification',
              icon: Icons.qr_code_2_rounded,
              children: [
                _pair(
                  IcueTextField(
                    controller: _make,
                    label: 'Manufacturer',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _maxLength(value, 60, 'Manufacturer'),
                  ),
                  IcueTextField(
                    controller: _model,
                    label: 'Model',
                    textInputAction: TextInputAction.next,
                    validator: (value) => _maxLength(value, 60, 'Model'),
                  ),
                ),
                IcueTextField(
                  controller: _serial,
                  label: 'Serial number',
                  helperText: _units > 1
                      ? 'A serial belongs to one unit; register one at a time'
                      : null,
                  enabled: _units <= 1,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _maxLength(value, 60, 'Serial'),
                ),
                _pair(
                  labelled(
                    'Condition',
                    AssetCondition.values,
                    _condition,
                    (value) => setState(() => _condition = value!),
                  ),
                  IcueTextField(
                    controller: _location,
                    label: 'Location',
                    hintText: 'Room, shelf',
                    textInputAction: TextInputAction.next,
                    validator: (value) => _maxLength(value, 80, 'Location'),
                  ),
                ),
              ],
            ),
            IcueFormSectionCard(
              title: 'Purchase and warranty',
              icon: Icons.receipt_long_outlined,
              children: [
                _pair(
                  optionalDate(
                    context,
                    _purchased,
                    'Purchase date',
                    first: past,
                    last: now,
                  ),
                  IcueTextField(
                    controller: _price,
                    label: 'Purchase price',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [decimalInputFormatter],
                    validator: _validatePrice,
                  ),
                ),
                _pair(
                  IcueDateField(
                    controller: _warrantyStart,
                    label: 'Warranty start',
                    firstDate: past,
                    lastDate: future,
                    clearable: true,
                    validator: _validateWarrantyStart,
                  ),
                  IcueDateField(
                    controller: _warrantyEnd,
                    label: 'Warranty end',
                    firstDate: past,
                    lastDate: future,
                    clearable: true,
                    validator: _validateWarrantyEnd,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: IcueButton(
                    label: _busy
                        ? 'Saving…'
                        : _units > 1
                        ? 'Register $_units assets'
                        : 'Register asset',
                    onPressed: _busy ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _sampleAssets = [
  (
    name: 'Teacher laptop',
    serial: 'DL7421XK01',
    make: 'Dell',
    model: 'Latitude 3440',
    price: '48500',
    location: 'Staff room',
  ),
  (
    name: 'Classroom projector',
    serial: 'EP5530TQ22',
    make: 'Epson',
    model: 'EB-X06',
    price: '32900.50',
    location: 'Room 12',
  ),
  (
    name: 'Lab microscope',
    serial: 'OL2208MC07',
    make: 'Olympus',
    model: 'CX23',
    price: '27500',
    location: 'Science lab',
  ),
];
