import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Add or edit a variant: SKU plus one value per item variant attribute.
class VariantDialog extends StatefulWidget {
  const VariantDialog({super.key, required this.item, this.variant});

  final InventoryItem item;
  final InventoryVariant? variant;

  static Future<bool> show(
    BuildContext context,
    InventoryItem item, {
    InventoryVariant? variant,
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
    for (final variantAttr in widget.item.variantAttrs)
      variantAttr: TextEditingController(
        text: widget.variant?.attrs[variantAttr],
      ),
  };

  @override
  void dispose() {
    _sku.dispose();
    for (final controller in _attrs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = {
      for (final mapEntry in _attrs.entries)
        if (mapEntry.value.text.trim().isNotEmpty)
          mapEntry.key: mapEntry.value.text.trim(),
    };
    if (values.isEmpty ||
        (widget.variant == null && _sku.text.trim().isEmpty)) {
      showMessage(context, 'SKU and at least one attribute are required');
      return;
    }
    final variant = widget.variant;
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveVariant({
        'itemId': widget.item.id,
        if (variant != null) 'id': variant.id else 'code': _sku.text.trim(),
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
          for (final mapEntry in _attrs.entries)
            TextField(
              controller: mapEntry.value,
              decoration: InputDecoration(labelText: mapEntry.key),
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
