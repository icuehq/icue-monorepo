import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Adds a category (or a subcategory of [parentId]) or edits [category]: a dialog on wide screens, a full screen on phones.
class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.category, this.parentId});

  final InventoryCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    InventoryCategory? category,
    String? parentId,
  }) => showFormPage(
    context,
    () => CategoryDialog(category: category, parentId: parentId),
  );

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String? _parentId = widget.category?.parentId ?? widget.parentId;
  late Tracking _tracking =
      widget.category?.suggestedTracking ?? Tracking.quantity;
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in [_name, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form with the next sample whose name is not taken yet (debug builds, new categories only).
  void _fillSample() {
    final taken = {
      for (final category in context.read<InventoryProvider>().categories)
        category.name.trim().toLowerCase(),
    };
    for (var tried = 0; tried < _sampleCategories.length; tried++) {
      final sample =
          _sampleCategories[_nextSample++ % _sampleCategories.length];
      if (taken.contains(sample.name.toLowerCase())) continue;
      setState(() {
        _name.text = sample.name;
        _description.text = sample.description;
        _tracking = sample.tracking;
      });
      return;
    }
    setState(() => _errorMessage = 'All sample categories already exist');
  }

  /// Required, and unique among categories (compared ignoring case).
  String? _validateName(String? value) {
    final required = requiredText(value);
    if (required != null) return required;
    final name = value!.trim().toLowerCase();
    final exists = context.read<InventoryProvider>().categories.any(
      (category) =>
          category.id != widget.category?.id &&
          category.name.trim().toLowerCase() == name,
    );
    return exists ? '"${value.trim()}" already exists' : null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final category = widget.category;
    final provider = context.read<InventoryProvider>();
    final name = _name.text.trim();
    final saved = await submitAndClose<InventoryProvider>(
      context,
      () => provider.saveCategory({
        if (category != null) 'id': category.id,
        'name': name,
        'description': blankToNull(_description),
        'parentId': _parentId,
        'suggestedTracking': _tracking.name,
      }),
    );
    if (mounted && !saved) {
      setState(() {
        _busy = false;
        _errorMessage = provider.errorMessage ?? 'Could not save category';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final editing = widget.category != null;
    final tops = inventoryProvider.topCategories
        .where((category) => category.id != widget.category?.id)
        .toList();
    final parentCategory = inventoryProvider.category(_parentId);
    final title = editing
        ? 'Edit Category'
        : (_parentId != null ? 'New Subcategory' : 'New Category');

    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      editing
                          ? 'Update the name, parent and tracking.'
                          : 'Group items under a category.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode && !editing)
                IcueButton(
                  label: 'Fill sample',
                  onPressed: _busy ? null : _fillSample,
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.auto_fix_high_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          IcueFormSectionCard(
            title: 'Category Details',
            icon: Icons.category_outlined,
            children: [
              IcueTextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
                label: 'Name *',
                hintText: 'e.g. Science Lab Equipment',
                icon: Icons.label_outline,
              ),
              IcueDropdown<String?>(
                value: _parentId,
                items: [
                  const DropdownMenuItem(child: Text('None (top level)')),
                  for (final category in tops)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  if (parentCategory != null &&
                      !tops.any((category) => category.id == _parentId))
                    DropdownMenuItem(
                      value: parentCategory.id,
                      child: Text(parentCategory.name),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
                label: 'Parent category',
                icon: Icons.account_tree_outlined,
              ),
              IcueDropdown<Tracking>(
                value: _tracking,
                items: [
                  for (final tracking in Tracking.values)
                    DropdownMenuItem(
                      value: tracking,
                      child: Text(tracking.label),
                    ),
                ],
                onChanged: (tracking) {
                  if (tracking != null) setState(() => _tracking = tracking);
                },
                label: 'Suggested tracking *',
                icon: Icons.track_changes_outlined,
              ),
              IcueTextField(
                controller: _description,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                label: 'Description',
                hintText: 'Optional notes or description',
                icon: Icons.description_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IcueButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: IcueButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              IcueButton(
                label: _busy
                    ? 'Saving…'
                    : (editing ? 'Save changes' : 'Create category'),
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.check_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _sampleCategories =
    <({String name, String description, Tracking tracking})>[
      (
        name: 'Stationery',
        description: 'Paper, pens, files and office supplies.',
        tracking: Tracking.quantity,
      ),
      (
        name: 'Laboratory Chemicals',
        description: 'Reagents and consumables with batch and expiry dates.',
        tracking: Tracking.batch,
      ),
      (
        name: 'Sports Equipment',
        description: 'Balls, nets, kits and training gear.',
        tracking: Tracking.quantity,
      ),
      (
        name: 'IT Hardware',
        description: 'Computers, projectors and peripherals.',
        tracking: Tracking.asset,
      ),
      (
        name: 'Cleaning Supplies',
        description: 'Consumables for housekeeping.',
        tracking: Tracking.quantity,
      ),
    ];
