import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class CategoryFormPage extends StatefulWidget {
  const CategoryFormPage({
    super.key,
    this.category,
    this.categoryId,
    this.parentId,
  });

  final InventoryCategory? category;
  final String? categoryId;
  final String? parentId;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _form = GlobalKey<FormState>();
  late final InventoryCategory? _existingCategory =
      widget.category ??
      (widget.categoryId != null
          ? context.read<InventoryProvider>().category(widget.categoryId!)
          : null);
  late final _code = TextEditingController(text: _existingCategory?.code);
  late final _name = TextEditingController(text: _existingCategory?.name);
  late final _description = TextEditingController(
    text: _existingCategory?.description,
  );
  late String? _parentId = _existingCategory?.parentId ?? widget.parentId;
  late Tracking _tracking =
      _existingCategory?.suggestedTracking ?? Tracking.quantity;
  bool _codeManuallyEdited = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        inventoryProvider.loadMasters();
      });
    }
  }

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
    final category = _existingCategory;
    final provider = context.read<InventoryProvider>();
    await submitAndClose<InventoryProvider>(
      context,
      () => provider.saveCategory({
        if (category != null) 'id': category.id else 'code': _code.text.trim(),
        'name': _name.text.trim(),
        'description': blankToNull(_description),
        'parentId': _parentId,
        'suggestedTracking': _tracking.name,
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final editing = _existingCategory != null;
    final tops = inventoryProvider.topCategories
        .where((category) => category.id != _existingCategory?.id)
        .toList();
    final parentCategory = _parentId != null
        ? inventoryProvider.category(_parentId)
        : null;
    final title = editing
        ? 'Edit category'
        : (_parentId != null ? 'New subcategory' : 'New category');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: CenteredBody(
        maxWidth: Breakpoints.formMaxWidth,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              FormSectionCard(
                title: 'Category Details',
                icon: Icons.category_outlined,
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      hintText: 'e.g. Science Lab Equipment',
                      prefixIcon: Icon(Icons.label_outline, size: 20),
                    ),
                    validator: requiredText,
                    onChanged: (value) {
                      if (!editing && !_codeManuallyEdited) {
                        _code.text = generateCategoryCode(value);
                      }
                    },
                  ),
                  TextFormField(
                    controller: _code,
                    enabled: !editing,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Code *',
                      prefixIcon: const Icon(
                        Icons.qr_code_2_outlined,
                        size: 20,
                      ),
                      helperText: editing
                          ? null
                          : 'Unique code (e.g. BKD, CLN)',
                    ),
                    validator: (value) {
                      final required = requiredText(value);
                      if (required != null) return required;
                      if (!editing) {
                        final code = value!.trim().toLowerCase();
                        final exists = inventoryProvider.categories.any(
                          (existing) =>
                              existing.code.trim().toLowerCase() == code ||
                              existing.id == code,
                        );
                        if (exists) return 'Code "$value" already exists';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _codeManuallyEdited = value.trim().isNotEmpty;
                    },
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _parentId,
                    decoration: const InputDecoration(
                      labelText: 'Parent category',
                      prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(child: Text('None (top level)')),
                      for (final category in tops)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      if (_parentId != null &&
                          parentCategory != null &&
                          !tops.any((category) => category.id == _parentId))
                        DropdownMenuItem(
                          value: parentCategory.id,
                          child: Text(parentCategory.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _parentId = value),
                  ),
                  DropdownButtonFormField<Tracking>(
                    initialValue: _tracking,
                    decoration: const InputDecoration(
                      labelText: 'Suggested tracking *',
                      prefixIcon: Icon(Icons.track_changes_outlined, size: 20),
                    ),
                    items: [
                      for (final tracking in Tracking.values)
                        DropdownMenuItem(
                          value: tracking,
                          child: Text(tracking.label),
                        ),
                    ],
                    onChanged: (tracking) {
                      if (tracking != null) {
                        setState(() => _tracking = tracking);
                      }
                    },
                  ),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional notes or description',
                      prefixIcon: Icon(Icons.description_outlined, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _busy
                        ? 'Saving…'
                        : (editing ? 'Save Changes' : 'Create Category'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
