import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category, this.parentId});

  final InventoryCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    InventoryCategory? category,
    String? parentId,
  }) => showFormSheet(
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
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String? _parentId = widget.category?.parentId ?? widget.parentId;
  late Tracking _tracking =
      widget.category?.suggestedTracking ?? Tracking.quantity;
  bool _codeManuallyEdited = false;
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
    await submitAndClose<InventoryProvider>(
      context,
      () => context.read<InventoryProvider>().saveCategory({
        if (category != null) 'id': category.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'parentId': _parentId,
        'suggestedTracking': _tracking.name,
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tops = context
        .read<InventoryProvider>()
        .topCategories
        .where((category) => category.id != widget.category?.id)
        .toList();
    final editing = widget.category != null;
    final title = editing
        ? 'Edit Category'
        : (widget.parentId != null ? 'New Subcategory' : 'New Category');

    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: requiredText,
            onChanged: (value) {
              if (widget.category == null && !_codeManuallyEdited) {
                _code.text = generateCategoryCode(value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Code
          TextFormField(
            controller: _code,
            enabled: !editing,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Code *',
              helperText: editing ? null : 'Unique code (e.g. BKD, CLN)',
            ),
            validator: requiredText,
            onChanged: (value) => _codeManuallyEdited = value.trim().isNotEmpty,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Parent Category
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

          // Suggested Tracking
          DropdownButtonFormField<Tracking>(
            initialValue: _tracking,
            decoration: const InputDecoration(
              labelText: 'Suggested tracking *',
            ),
            items: [
              for (final tracking in Tracking.values)
                DropdownMenuItem(value: tracking, child: Text(tracking.label)),
            ],
            onChanged: (tracking) => _tracking = tracking ?? _tracking,
          ),
          const SizedBox(height: 24),

          // Submit action
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _busy
                  ? 'Saving…'
                  : (editing ? 'Save Changes' : 'Create Category'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Auto-generates an uppercase category code based on the category name.
String generateCategoryCode(String name) {
  final clean = name.trim().toUpperCase();
  if (clean.isEmpty) return '';
  final words = clean
      .split(RegExp(r'[^A-Z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    return words.first.substring(0, words.first.length.clamp(0, 3));
  }
  if (words.length == 2) {
    final first = words[0];
    final second = words[1];
    return '${first.substring(0, first.length.clamp(0, 2))}${second[0]}';
  }
  return words.take(4).map((word) => word[0]).join();
}
