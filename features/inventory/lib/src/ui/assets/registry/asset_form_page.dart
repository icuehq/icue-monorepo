import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_batch_banner.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_form_sections.dart';
import 'package:inventory/src/ui/assets/registry/widgets/sample_assets.dart';
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

  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _price = TextEditingController();
  final _purchased = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _warrantyEnd = TextEditingController();
  InventoryItem? _item;
  String? _store;
  var _condition = 'new';
  var _busy = false;
  var _submitted = false;
  var _dirty = false;
  var _nextSample = 0;

  int get _units => int.tryParse(_quantity.text.trim()) ?? 1;
  double? get _unitPrice => double.tryParse(_price.text.trim());
  double? get _totalPrice => _unitPrice != null ? _unitPrice! * _units : null;

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
      _purchased,
      _warrantyStart,
      _warrantyEnd,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final store = _store;
    if (store == null) {
      showMessage(context, 'Select a store first');
      return;
    }
    final picked = await pickItem(context, assetsOnly: true, storeId: store);
    if (picked == null || !mounted) return;
    if (picked.item.tracking != Tracking.asset) {
      showMessage(
        context,
        '${picked.item.name} is not tracked as an individual asset',
      );
      return;
    }
    setState(() {
      _dirty = true;
      _item = picked.item;
      if (_name.text.isEmpty) _name.text = picked.item.name;
    });
  }

  /// Items belong to one store, so changing the store clears a pick from another.
  void _changeStore(String? value) => setState(() {
    _dirty = true;
    _store = value;
    if (_item?.storeId != value) _item = null;
  });

  String? _cleanText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
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

  Future<bool> _confirmDiscard() => IcueDialog.confirm(
    context,
    title: 'Discard registration?',
    message: 'You have unsaved changes. Leaving now will discard them.',
    confirmLabel: 'Discard',
    destructive: true,
  );

  /// Fills the form with the next sample (debug builds only); picks the first asset-tracked item when none is chosen.
  Future<void> _fillSample() async {
    final inventoryProvider = context.read<InventoryProvider>();
    final stores = inventoryProvider.stores.where((store) => store.active);
    final store = _store ?? (stores.isEmpty ? null : stores.first.id);
    if (_item == null) {
      await inventoryProvider.loadItems(
        search: '',
        clearCategory: true,
        storeId: store,
      );
      if (!mounted) return;
    }
    final assetItems = inventoryProvider.items.where(
      (item) => item.tracking == Tracking.asset && item.storeId == store,
    );
    final sample = sampleAssets[_nextSample++ % sampleAssets.length];
    final today = DateTime.now();
    setState(() {
      _dirty = true;
      _store = store;
      _item ??= assetItems.isEmpty ? null : assetItems.first;
      _name.text = sample.name;
      _quantity.text = '1';
      _serial.text = sample.serial;
      _make.text = sample.make;
      _model.text = sample.model;
      _price.text = sample.price;
      _condition = 'new';
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
    final ok = await assetSubmit(
      context,
      (assetsProvider) => assetsProvider.act('inventory-asset-register', {
        'itemId': _item!.id,
        'storeId': _store,
        'quantity': units,
        'name': _cleanText(_name),
        'serialNumber': units > 1 ? null : _cleanText(_serial),
        'make': _cleanText(_make),
        'model': _cleanText(_model),
        'purchaseDate': _cleanText(_purchased),
        'price': double.tryParse(_price.text.trim()),
        'warrantyStart': _cleanText(_warrantyStart),
        'warrantyEnd': _cleanText(_warrantyEnd),
        'condition': _condition,
      }, requestId: _requestId),
      done: units > 1 ? '$units assets registered' : 'Asset registered',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) _dirty = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await _confirmDiscard()) navigator.pop();
    },
    child: Scaffold(
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
      body: IcueCenteredBody(
        child: Form(
          key: _form,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 840;
              final assetSection = AssetSectionCard(
                item: _item,
                onPick: _pick,
                nameController: _name,
                store: _store,
                onStoreChanged: _changeStore,
                quantityController: _quantity,
                units: _units,
                maxQuantity: _maxQuantity,
                onQuantityChanged: () => setState(() {
                  _dirty = true;
                  if (_units > 1) _serial.clear();
                }),
              );
              final identificationSection = AssetIdentificationCard(
                makeController: _make,
                modelController: _model,
                serialController: _serial,
                units: _units,
                condition: _condition,
                onConditionChanged: (value) => setState(() {
                  _dirty = true;
                  _condition = value!;
                }),
              );
              final purchaseSection = AssetPurchaseCard(
                purchasedController: _purchased,
                priceController: _price,
                warrantyStartController: _warrantyStart,
                warrantyEndController: _warrantyEnd,
                units: _units,
                totalPrice: _totalPrice,
                onPriceChanged: () => setState(() {
                  _dirty = true;
                }),
                validateWarrantyStart: _validateWarrantyStart,
                validateWarrantyEnd: _validateWarrantyEnd,
              );
              final batchBanner = _units > 1
                  ? AssetBatchBanner(units: _units)
                  : null;

              return ListView(
                padding: EdgeInsets.all(twoColumns ? 24 : 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [assetSection, identificationSection],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [?batchBanner, purchaseSection],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    ?batchBanner,
                    assetSection,
                    identificationSection,
                    purchaseSection,
                  ],
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: IcueBreakpoints.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: IcueButton(
                        label: 'Cancel',
                        variant: IcueButtonVariant.outline,
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: IcueButton(
                        label: _busy
                            ? 'Registering…'
                            : _units > 1
                            ? 'Register $_units assets'
                            : 'Register asset',
                        leadingIcon: Icons.check_circle_outline_rounded,
                        isLoading: _busy,
                        onPressed: _busy ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
