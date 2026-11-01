import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category, this.parentId});

  final InvCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    InvCategory? category,
    String? parentId,
  }) => showInvSheet(
    context,
    () => CategoryFormSheet(category: category, parentId: parentId),
  );

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _code = TextEditingController(text: widget.category?.code);
  late final _name = TextEditingController(text: widget.category?.name);
  late final _desc = TextEditingController(text: widget.category?.description);
  late String? _parentId = widget.category?.parentId ?? widget.parentId;
  late Tracking _tracking = widget.category?.suggestedTracking ?? Tracking.qty;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final c = widget.category;
    await invSubmit(
      context,
      () => context.read<InventoryProvider>().saveCategory({
        if (c != null) 'id': c.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'parentId': _parentId,
        'suggestedTracking': _tracking.name,
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final tops = context
        .read<InventoryProvider>()
        .topCategories
        .where((c) => c.id != widget.category?.id)
        .toList();
    final editing = widget.category != null;
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: !editing,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code *'),
            validator: requiredText,
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: requiredText,
          ),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(labelText: 'Parent category'),
            items: [
              const DropdownMenuItem(child: Text('None (top level)')),
              for (final c in tops)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => _parentId = v,
          ),
          DropdownButtonFormField<Tracking>(
            initialValue: _tracking,
            decoration: const InputDecoration(
              labelText: 'Suggested tracking *',
            ),
            items: [
              for (final t in Tracking.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => _tracking = v ?? _tracking,
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
