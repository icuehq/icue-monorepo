import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibCategorySheet extends StatefulWidget {
  const LibCategorySheet({super.key, this.category, this.parentId});

  final LibCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    LibCategory? category,
    String? parentId,
  }) => showInvSheet(
    context,
    () => LibCategorySheet(category: category, parentId: parentId),
  );

  @override
  State<LibCategorySheet> createState() => _LibCategorySheetState();
}

class _LibCategorySheetState extends State<LibCategorySheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _code = TextEditingController(text: widget.category?.code);
  late final _name = TextEditingController(text: widget.category?.name);
  late final _desc = TextEditingController(text: widget.category?.description);
  late String? _parentId = widget.category?.parentId ?? widget.parentId;
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
    await libSubmit(
      context,
      () => context.read<LibraryProvider>().saveCategory({
        if (c != null) 'id': c.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': blankToNull(_desc),
        'parentId': _parentId,
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final tops = context
        .read<LibraryProvider>()
        .topCategories
        .where((c) => c.id != widget.category?.id)
        .toList();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: widget.category == null,
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
