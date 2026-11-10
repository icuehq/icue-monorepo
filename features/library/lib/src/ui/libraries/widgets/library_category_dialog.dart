import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/mock_books.dart';

class LibraryCategoryDialog extends StatefulWidget {
  const LibraryCategoryDialog({super.key, this.category, this.parentId});

  final LibraryCategory? category;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    LibraryCategory? category,
    String? parentId,
  }) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Breakpoints.formMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LibraryCategoryDialog(category: category, parentId: parentId),
        ),
      ),
    ),
  );

  @override
  State<LibraryCategoryDialog> createState() => _LibraryCategoryDialogState();
}

class _LibraryCategoryDialogState extends State<LibraryCategoryDialog> {
  final _form = GlobalKey<FormState>();
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
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  int _mockIndex = 0;

  /// Fills the next sample category not already under the chosen parent (client-side only).
  void _prefillMock() {
    final taken = {
      for (final category in context.read<LibraryProvider>().categories)
        if (category.parentId == _parentId) category.name.trim().toLowerCase(),
    };
    for (var step = 0; step < mockCategories.length; step++) {
      final (name, description) =
          mockCategories[(_mockIndex + step) % mockCategories.length];
      if (taken.contains(name.toLowerCase())) continue;
      _mockIndex += step + 1;
      setState(() {
        _name.text = name;
        _description.text = description;
      });
      return;
    }
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
        if (category != null) 'id': category.id,
        'name': _name.text.trim(),
        'description': blankToNull(_description),
        'parentId': _parentId,
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
    final libraryProvider = context.read<LibraryProvider>();
    final editing = widget.category != null;
    final tops = libraryProvider.topCategories
        .where((category) => category.id != widget.category?.id)
        .toList();
    final parentCategory = _parentId != null
        ? libraryProvider.category(_parentId)
        : null;

    final title = editing
        ? 'Edit Category'
        : (_parentId != null ? 'New Subcategory' : 'New Category');

    final subtitle = editing
        ? 'Update category identification, display name, and parent hierarchy.'
        : (_parentId != null
              ? 'Add a nested subcategory under "${parentCategory?.name ?? 'parent category'}".'
              : 'Create a top-level book classification or genre for the catalogue.');

    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
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
                  Icons.auto_stories_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
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
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error Callout
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

          // Card Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Category Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  label: 'Category name *',
                  hintText: 'e.g. Science Fiction, Pure Sciences',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _buildParentField(tops),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  label: 'Description',
                  hintText: 'Optional notes on titles in this category…',
                  icon: Icons.notes_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!editing) ...[
                AppButton(
                  label: 'Fill sample',
                  onPressed: _busy ? null : _prefillMock,
                  variant: AppButtonVariant.ghost,
                  leadingIcon: Icons.auto_fix_high_rounded,
                ),
                const Spacer(),
              ],
              AppButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: AppButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              AppButton(
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

  /// Required, and unique among the categories under the same parent (compared ignoring case).
  String? _validateName(String? value) {
    final required = requiredText(value);
    if (required != null) return required;
    final name = value!.trim().toLowerCase();
    final exists = context.read<LibraryProvider>().categories.any(
      (category) =>
          category.id != widget.category?.id &&
          category.parentId == _parentId &&
          category.name.trim().toLowerCase() == name,
    );
    return exists ? '"${value.trim()}" already exists here' : null;
  }

  Widget _buildParentField(List<LibraryCategory> tops) {
    return AppDropdown<String?>(
      value: _parentId,
      items: [
        const DropdownMenuItem(child: Text('None (top level)')),
        for (final category in tops)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
      ],
      onChanged: (value) => setState(() => _parentId = value),
      label: 'Parent category',
      icon: Icons.account_tree_outlined,
    );
  }
}
