import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class StoreFormSheet extends StatefulWidget {
  const StoreFormSheet({super.key, this.store});

  final InvStore? store;

  static Future<void> show(BuildContext context, {InvStore? store}) =>
      showInvSheet(context, () => StoreFormSheet(store: store));

  @override
  State<StoreFormSheet> createState() => _StoreFormSheetState();
}

class _StoreFormSheetState extends State<StoreFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _code = TextEditingController(text: widget.store?.code);
  late final _name = TextEditingController(text: widget.store?.name);
  late final _desc = TextEditingController(text: widget.store?.description);
  late final _location = TextEditingController(text: widget.store?.location);
  // ponytail: ERP staff IDs typed in; a staff picker needs the Node staff endpoint.
  late final _keepers = TextEditingController(
    text: widget.store?.storekeeperIds.join(', '),
  );
  late int? _campus = widget.store?.campusId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_code, _name, _desc, _location, _keepers]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _keeperError(String? v) {
    final parts = (v ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return parts.every((s) => int.tryParse(s) != null)
        ? null
        : 'Comma-separated staff IDs';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = widget.store;
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await invSubmit(
      context,
      () => context.read<InventoryProvider>().saveStore({
        if (s != null) 'id': s.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'campusId': _campus,
        'description': blank(_desc),
        'location': blank(_location),
        'storekeeperIds': [
          for (final p in _keepers.text.split(','))
            if (p.trim().isNotEmpty) int.parse(p.trim()),
        ],
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<InventoryProvider>().access;
    final editing = widget.store != null;
    final campuses = {...access.campuses, ?_campus}.toList();
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
              for (final c in campuses)
                DropdownMenuItem(value: c, child: Text('Campus $c')),
            ],
            onChanged: editing ? null : (v) => _campus = v,
            validator: (v) => v == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextFormField(
            controller: _desc,
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
