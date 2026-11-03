import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
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
  }) => showFormPage(
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
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final category = widget.category;
    final provider = context.read<LibraryProvider>();
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => provider.saveCategory({
        if (category != null) 'id': category.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': blankToNull(_description),
        'parentId': _parentId,
      }),
    );
    if (mounted && !saved) {
      setState(() {
        _busy = false;
        _errorMessage = provider.errorMessage ?? 'Could not save';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tops = context
        .read<LibraryProvider>()
        .topCategories
        .where((category) => category.id != widget.category?.id)
        .toList();
    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: widget.category == null,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code *'),
            validator: (value) {
              final required = requiredText(value);
              if (required != null) return required;
              if (widget.category == null) {
                final code = value!.trim().toLowerCase();
                final exists = context.read<LibraryProvider>().categories.any(
                  (c) => c.code.trim().toLowerCase() == code || c.id == code,
                );
                if (exists) return 'Code "$value" already exists';
              }
              return null;
            },
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: requiredText,
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
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
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
