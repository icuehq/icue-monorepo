import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Add or edit a variant: SKU plus one value per item variant attribute.
class VariantDialog extends StatefulWidget {
  const VariantDialog({super.key, required this.item, this.variant});

  final InvItem item;
  final InvVariant? variant;

  static Future<bool> show(
    BuildContext context,
    InvItem item, {
    InvVariant? variant,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => VariantDialog(item: item, variant: variant),
      ) ??
      false;

  @override
  State<VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<VariantDialog> {
  final _requestId = newRequestId();
  late final _sku = TextEditingController(text: widget.variant?.sku);
  late final _attrs = {
    for (final a in widget.item.variantAttrs)
      a: TextEditingController(text: widget.variant?.attrs[a]),
  };

  @override
  void dispose() {
    _sku.dispose();
    for (final c in _attrs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = {
      for (final e in _attrs.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (values.isEmpty ||
        (widget.variant == null && _sku.text.trim().isEmpty)) {
      invSnack(context, 'SKU and at least one attribute are required');
      return;
    }
    final v = widget.variant;
    await invSubmit(
      context,
      () => context.read<InventoryProvider>().saveVariant({
        'itemId': widget.item.id,
        if (v != null) 'id': v.id else 'code': _sku.text.trim(),
        'attrs': values,
      }, requestId: _requestId),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.variant == null ? 'Add variant' : 'Edit variant'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _sku,
            enabled: widget.variant == null,
            decoration: const InputDecoration(labelText: 'SKU *'),
          ),
          for (final e in _attrs.entries)
            TextField(
              controller: e.value,
              decoration: InputDecoration(labelText: e.key),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
