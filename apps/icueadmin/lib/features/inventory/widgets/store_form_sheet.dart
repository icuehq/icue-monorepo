import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class StoreFormSheet extends StatefulWidget {
  const StoreFormSheet({super.key, this.store});

  final InventoryStore? store;

  static Future<void> show(BuildContext context, {InventoryStore? store}) =>
      showFormSheet(context, () => StoreFormSheet(store: store));

  @override
  State<StoreFormSheet> createState() => _StoreFormSheetState();
}

class _StoreFormSheetState extends State<StoreFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _code = TextEditingController(text: widget.store?.code);
  late final _name = TextEditingController(text: widget.store?.name);
  late final _description = TextEditingController(
    text: widget.store?.description,
  );
  late final _location = TextEditingController(text: widget.store?.location);
  // ponytail: ERP staff IDs typed in; a staff picker needs the Node staff endpoint.
  late final _keepers = TextEditingController(
    text: widget.store?.storekeeperIds.join(', '),
  );
  late int? _campus = widget.store?.campusId;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _description,
      _location,
      _keepers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _keeperError(String? currentValue) {
    final parts = (currentValue ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    return parts.every((part) => int.tryParse(part) != null)
        ? null
        : 'Comma-separated staff IDs';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final store = widget.store;
    String? blank(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveStore({
        if (store != null) 'id': store.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'campusId': _campus,
        'description': blank(_description),
        'location': blank(_location),
        'storekeeperIds': [
          for (final value in _keepers.text.split(','))
            if (value.trim().isNotEmpty) int.parse(value.trim()),
        ],
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final editing = widget.store != null;
    final campuses = {...access.campusIds, ?_campus}.toList();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: !editing,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Store code *'),
            validator: requiredText,
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Store name *'),
            validator: requiredText,
          ),
          DropdownButtonFormField<int>(
            initialValue: _campus,
            decoration: const InputDecoration(labelText: 'Campus *'),
            items: [
              for (final value in campuses)
                DropdownMenuItem(value: value, child: Text('Campus $value')),
            ],
            onChanged: editing ? null : (value) => _campus = value,
            validator: (value) => value == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextFormField(
            controller: _keepers,
            decoration: const InputDecoration(
              labelText: 'Storekeeper staff IDs',
            ),
            validator: _keeperError,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
