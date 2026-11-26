import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_form_sections.dart';
import 'package:inventory/src/ui/assets/registry/widgets/sample_assets.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Registers one received (unregistered) asset unit with its name, make, serial number, purchase and warranty details.
class AssetFormPage extends StatefulWidget {
  const AssetFormPage({required this.assetId, super.key});

  final String assetId;

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _price = TextEditingController();
  final _purchased = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _warrantyEnd = TextEditingController();
  InventoryAsset? _asset;
  String? _loadError;
  var _condition = 'new';
  var _busy = false;
  var _submitted = false;
  var _dirty = false;
  var _nextSample = 0;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
    _loadAsset();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serial,
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

  Future<void> _loadAsset() async {
    final assetsProvider = context.read<AssetsProvider>();
    final asset = await assetsProvider.asset(widget.assetId);
    if (asset != null) await assetsProvider.loadItemNames([asset.itemId]);
    if (!mounted) return;
    setState(() {
      _asset = asset;
      if (asset == null) {
        _loadError = assetsProvider.errorMessage ?? 'Asset not found';
      } else if (!asset.isUnregistered) {
        _loadError = 'This asset is already registered';
      } else {
        _name.text = asset.name;
        if (asset.price != null) _price.text = '${asset.price}';
      }
    });
  }

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

  /// Fills the form with the next sample (debug builds only).
  void _fillSample() {
    final sample = sampleAssets[_nextSample++ % sampleAssets.length];
    final today = DateTime.now();
    setState(() {
      _dirty = true;
      _name.text = sample.name;
      _serial.text = sample.serial;
      _make.text = sample.make;
      _model.text = sample.model;
      _price.text = sample.price;
      _condition = 'new';
      _purchased.text = today.subtract(const Duration(days: 30)).toApiDate();
      _warrantyStart.text = _purchased.text;
      _warrantyEnd.text = today.add(const Duration(days: 700)).toApiDate();
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await assetSubmit(
      context,
      (assetsProvider) => assetsProvider.act('inventory-asset-register', {
        'id': widget.assetId,
        'name': _cleanText(_name),
        'serialNumber': _cleanText(_serial),
        'make': _cleanText(_make),
        'model': _cleanText(_model),
        'purchaseDate': _cleanText(_purchased),
        'price': double.tryParse(_price.text.trim()),
        'warrantyStart': _cleanText(_warrantyStart),
        'warrantyEnd': _cleanText(_warrantyEnd),
        'condition': _condition,
      }, requestId: _requestId),
      done: 'Asset registered',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) _dirty = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null || _loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Register asset')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Text(_loadError!),
        ),
      );
    }
    return _formPage(context, asset);
  }

  Widget _formPage(BuildContext context, InventoryAsset asset) => PopScope(
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
              final received = AssetReceivedCard(
                asset: asset,
                itemName: context.read<AssetsProvider>().itemName(asset.itemId),
                storeName:
                    context
                        .read<InventoryProvider>()
                        .stores
                        .where((store) => store.id == asset.storeId)
                        .firstOrNull
                        ?.name ??
                    asset.storeId,
              );
              final identification = AssetIdentificationCard(
                nameController: _name,
                makeController: _make,
                modelController: _model,
                serialController: _serial,
                condition: _condition,
                onConditionChanged: (value) => setState(() {
                  _dirty = true;
                  _condition = value!;
                }),
              );
              final purchase = AssetPurchaseCard(
                purchasedController: _purchased,
                priceController: _price,
                warrantyStartController: _warrantyStart,
                warrantyEndController: _warrantyEnd,
                validateWarrantyStart: _validateWarrantyStart,
                validateWarrantyEnd: _validateWarrantyEnd,
              );
              return ListView(
                padding: EdgeInsets.all(twoColumns ? 24 : 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  received,
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identification),
                        const SizedBox(width: 16),
                        Expanded(child: purchase),
                      ],
                    )
                  else ...[
                    identification,
                    purchase,
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
                        label: _busy ? 'Registering…' : 'Register asset',
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
