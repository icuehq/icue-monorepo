import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
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
  final _wStart = TextEditingController();
  final _wEnd = TextEditingController();
  InvItem? _item;
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
    for (final c in [
      _name,
      _serial,
      _make,
      _model,
      _price,
      _location,
      _purchased,
      _wStart,
      _wEnd,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await pickItem(context, assets: true);
    if (r == null || !mounted) return;
    if (r.item.tracking != Tracking.asset) {
      invSnack(context, '${r.item.name} is not tracked as an individual asset');
      return;
    }
    setState(() {
      _item = r.item;
      _poId = null;
      if (_name.text.isEmpty) _name.text = r.item.name;
    });
  }

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_item == null) {
      invSnack(context, 'Choose an asset item');
      return;
    }
    setState(() => _busy = true);
    await assetSubmit(
      context,
      (p) => p.act('inv-asset-register', {
        'itemId': _item!.id,
        'storeId': _store,
        'name': _opt(_name),
        'serialNo': _opt(_serial),
        'make': _opt(_make),
        'model': _opt(_model),
        'poId': _poId,
        'purchaseDate': _opt(_purchased),
        'price': double.tryParse(_price.text.trim()),
        'warrantyStart': _opt(_wStart),
        'warrantyEnd': _opt(_wEnd),
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
      for (final o in context.watch<ProcurementProvider>().orders)
        if (const ['partially_received', 'fully_received'].contains(o.status) &&
            o.lines.any((l) => l.itemId == _item?.id))
          o,
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
              onChanged: (v) => setState(() => _store = v),
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
              InvAsset.conditions,
              _condition,
              (v) => setState(() => _condition = v!),
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
              _wStart,
              'Warranty start',
              first: past,
              last: now.add(const Duration(days: 3650)),
            ),
            optionalDate(
              context,
              _wEnd,
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
                for (final o in orders)
                  DropdownMenuItem(value: o.id, child: Text(o.number)),
              ],
              onChanged: (v) => setState(() => _poId = v),
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
