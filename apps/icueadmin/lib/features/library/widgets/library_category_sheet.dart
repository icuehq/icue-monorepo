import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibraryCategorySheet extends StatefulWidget {
  const LibraryCategorySheet({super.key, this.category, this.parentId});

  final LibraryCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    LibraryCategory? category,
    String? parentId,
  }) => showFormSheet(
    context,
    () => LibraryCategorySheet(category: category, parentId: parentId),
  );

  @override
  State<LibraryCategorySheet> createState() => _LibCategorySheetState();
}

class _LibCategorySheetState extends State<LibraryCategorySheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.category?.code);
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String? _parentId = widget.category?.parentId ?? widget.parentId;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final category = widget.category;
    await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().saveCategory({
        if (category != null) 'id': category.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': blankToNull(_description),
        'parentId': _parentId,
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final tops = context
        .read<LibraryProvider>()
        .topCategories
        .where((category) => category.id != widget.category?.id)
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
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(labelText: 'Parent category'),
            items: [
              const DropdownMenuItem(child: Text('None (top level)')),
              for (final category in tops)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => _parentId = value,
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
