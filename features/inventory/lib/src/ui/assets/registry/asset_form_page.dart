import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Registers one asset (FRS 10.19). A purchase order, when given, supplies the vendor and price and caps the units.
class AssetFormPage extends StatefulWidget {
  const AssetFormPage({super.key});

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
  final _location = TextEditingController();
  final _purchased = TextEditingController();
  final _warrantyStart = TextEditingController();
  final _warrantyEnd = TextEditingController();
  InventoryItem? _item;
  String? _poId;
  String? _store;
  var _condition = 'new';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadOrders(
        context.read<InventoryProvider>().access,
      );
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serial,
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
    final picked = await pickItem(context, assets: true);
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
      _poId = null;
      if (_name.text.isEmpty) _name.text = picked.item.name;
    });
  }

  String? _opt(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_item == null) {
      showMessage(context, 'Choose an asset item');
      return;
    }
    setState(() => _busy = true);
    await assetSubmit(
      context,
      (assetsProvider) => assetsProvider.act('inventory-asset-register', {
        'itemId': _item!.id,
        'storeId': _store,
        'name': _opt(_name),
        'serialNumber': _opt(_serial),
        'make': _opt(_make),
        'model': _opt(_model),
        'purchaseOrderId': _poId,
        'purchaseDate': _opt(_purchased),
        'price': double.tryParse(_price.text.trim()),
        'warrantyStart': _opt(_warrantyStart),
        'warrantyEnd': _opt(_warrantyEnd),
        'condition': _condition,
        'location': _opt(_location),
      }, requestId: _requestId),
      done: 'Asset registered',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 3650));
    final orders = [
      for (final purchaseOrder in context.watch<ProcurementProvider>().orders)
        if (const [
              'partially_received',
              'fully_received',
            ].contains(purchaseOrder.status) &&
            purchaseOrder.lineItems.any(
              (orderLine) => orderLine.itemId == _item?.id,
            ))
          purchaseOrder,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Register asset')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_item?.name ?? 'Choose asset item *'),
              subtitle: _item == null ? null : Text(_item!.code),
              trailing: const Icon(Icons.search),
              onTap: _pick,
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Asset name'),
            ),
            StoreDropdown(
              value: _store,
              onChanged: (value) => setState(() => _store = value),
            ),
            TextFormField(
              controller: _serial,
              decoration: const InputDecoration(labelText: 'Serial number'),
            ),
            TextFormField(
              controller: _make,
              decoration: const InputDecoration(labelText: 'Manufacturer'),
            ),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            labelled(
              'Condition',
              InventoryAsset.conditions,
              _condition,
              (value) => setState(() => _condition = value!),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (room, shelf)',
              ),
            ),
            optionalDate(
              context,
              _purchased,
              'Purchase date',
              first: past,
              last: now,
            ),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Purchase price'),
              validator: optionalNumber,
            ),
            optionalDate(
              context,
              _warrantyStart,
              'Warranty start',
              first: past,
              last: now.add(const Duration(days: 3650)),
            ),
            optionalDate(
              context,
              _warrantyEnd,
              'Warranty end',
              first: past,
              last: now.add(const Duration(days: 3650)),
            ),
            DropdownButtonFormField<String?>(
              key: ValueKey(_item?.id),
              initialValue: _poId,
              decoration: const InputDecoration(
                labelText: 'Purchase order (optional)',
                helperText: 'Takes vendor and price from the order; limited to its accepted units',
              ),
              items: [
                const DropdownMenuItem(child: Text('None')),
                for (final purchaseOrder in orders)
                  DropdownMenuItem(
                    value: purchaseOrder.id,
                    child: Text(purchaseOrder.number),
                  ),
              ],
              onChanged: (value) => setState(() => _poId = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Register'),
            ),
          ],
        ),
      ),
    );
  }
}
