import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_access_section.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_dialog_header.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
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
    scrollable: false,
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
  late String? _storeId = _resolveInitialStoreId();
  late List<int> _requesterRoleIds =
      widget.category?.requesterRoleIds ?? const [];
  late List<CategoryApprover> _approvers =
      widget.category?.approvers ?? const [];
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  String? _singleActiveStoreId(InventoryProvider provider) {
    final activeStores = [
      for (final store in provider.stores)
        if (store.active) store,
    ];
    return activeStores.length == 1 ? activeStores.single.id : null;
  }

  String? _resolveInitialStoreId() {
    if (widget.category != null) return widget.category!.storeId;
    final provider = context.read<InventoryProvider>();
    return widget.parentId != null
        ? provider.category(widget.parentId)?.storeId
        : _singleActiveStoreId(provider);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  /// Fills the form with the next sample whose name is not taken yet (debug builds, new categories only).
  void _fillSample() {
    final provider = context.read<InventoryProvider>();
    final targetStoreId =
        _storeId ??
        provider.stores.where((store) => store.active).firstOrNull?.id;
    final taken = {
      for (final category in provider.categories)
        if (category.storeId == targetStoreId)
          category.name.trim().toLowerCase(),
    };
    for (var tried = 0; tried < _sampleCategories.length; tried++) {
      final sample =
          _sampleCategories[_nextSample++ % _sampleCategories.length];
      if (taken.contains(sample.name.toLowerCase())) continue;
      setState(() {
        _errorMessage = null;
        _storeId ??= targetStoreId;
        _name.text = sample.name;
        _description.text = sample.description;
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
          category.storeId == _storeId &&
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
    final category = widget.category;
    final provider = context.read<InventoryProvider>();
    final storeId = _storeId ?? _singleActiveStoreId(provider);
    if (category == null && storeId == null) {
      setState(() => _errorMessage = 'Please select a store');
      return;
    }
    setState(() => _busy = true);
    final name = _name.text.trim();
    final saved = await submitAndClose<InventoryProvider>(
      context,
      () => provider.saveCategory({
        if (category != null) 'id': category.id,
        'name': name,
        'description': blankToNull(_description),
        'parentId': _parentId,
        if (category == null) 'storeId': storeId,
        // Only top-level categories carry request/approve settings.
        ...categoryAccessData(
          requesterRoleIds: _parentId == null ? _requesterRoleIds : const [],
          approvers: _parentId == null ? _approvers : const [],
        ),
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
    final wide = context.isWide;
    final inventoryProvider = context.watch<InventoryProvider>();
    final editing = widget.category != null;
    final availableStores = [
      for (final store in inventoryProvider.stores)
        if (store.active || store.id == _storeId) store,
    ];
    final showStoreField =
        !(inventoryProvider.restricted && availableStores.length == 1);
    if (!editing &&
        widget.parentId == null &&
        _storeId == null &&
        availableStores.length == 1) {
      final onlyStoreId = availableStores.single.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _storeId == null) {
          setState(() => _storeId = onlyStoreId);
        }
      });
    }

    final tops = inventoryProvider.topCategories
        .where(
          (category) =>
              category.id != widget.category?.id &&
              category.storeId == _storeId,
        )
        .toList();
    final parentCategory = inventoryProvider.category(_parentId);
    final hasSubcategories =
        editing &&
        inventoryProvider.categories.any(
          (category) => category.parentId == widget.category!.id,
        );

    final storeField = StoreDropdown(
      key: ValueKey('store_$_storeId'),
      label: 'Store *',
      value: _storeId,
      enabled: !editing && widget.parentId == null,
      prefixIcon: const Icon(Icons.store_outlined, size: 20),
      onChanged: (value) => setState(() {
        _errorMessage = null;
        _storeId = value;
        _parentId = null;
      }),
    );
    final parentField = _buildParentField(
      tops: tops,
      parentCategory: parentCategory,
      hasSubcategories: hasSubcategories,
    );

    return IcueCenteredBody(
      maxWidth: IcueBreakpoints.formMaxWidth,
      child: Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryDialogHeader(
              editing: editing,
              isSubcategory: _parentId != null,
              inactive: editing && !widget.category!.active,
              parentName: parentCategory?.name,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      _buildCallout(
                        theme,
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                        isError: true,
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
                          onChanged: (_) => _clearError(),
                          label: 'Name *',
                          hintText: 'e.g. Science Lab Equipment',
                          icon: Icons.label_outline,
                        ),
                        if (wide && showStoreField)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: storeField),
                              const SizedBox(width: 14),
                              Expanded(child: parentField),
                            ],
                          )
                        else ...[
                          if (showStoreField) storeField,
                          parentField,
                        ],
                        IcueTextField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _clearError(),
                          label: 'Description',
                          hintText: 'Optional notes or description',
                          icon: Icons.description_outlined,
                        ),
                      ],
                    ),
                    if (_parentId != null) ...[
                      _buildCallout(
                        theme,
                        icon: Icons.info_outline_rounded,
                        message:
                            'Requests and approvals follow ${parentCategory?.name ?? 'the parent category'}.',
                      ),
                      const SizedBox(height: 16),
                    ] else
                      CategoryAccessSection(
                        requesterRoleIds: _requesterRoleIds,
                        approvers: _approvers,
                        onRequesterRolesChanged: (roleIds) =>
                            setState(() => _requesterRoleIds = roleIds),
                        onApproversChanged: (approvers) =>
                            setState(() => _approvers = approvers),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildActions(editing: editing, wide: wide),
          ],
        ),
      ),
    );
  }

  Widget _buildCallout(
    ThemeData theme, {
    required IconData icon,
    required String message,
    bool isError = false,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? theme.colorScheme.error.withValues(alpha: 0.08)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color:
            (isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outlineVariant)
                .withValues(alpha: isError ? 0.3 : 0.5),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isError ? theme.colorScheme.error : theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: isError ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildParentField({
    required List<InventoryCategory> tops,
    required InventoryCategory? parentCategory,
    required bool hasSubcategories,
  }) {
    final disabled = _storeId == null || hasSubcategories;
    final helperText = _storeId == null
        ? 'Select a store first'
        : hasSubcategories
        ? 'Categories with subcategories must stay top level'
        : (tops.isEmpty && parentCategory == null)
        ? 'No top-level categories in this store yet'
        : null;

    return IcueDropdown<String?>(
      key: ValueKey('parent_${_storeId ?? 'none'}'),
      value: _parentId,
      items: [
        const DropdownMenuItem(child: Text('None (top level)')),
        for (final category in tops)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
        if (parentCategory != null &&
            !tops.any((category) => category.id == _parentId))
          DropdownMenuItem(
            value: parentCategory.id,
            child: Text(parentCategory.name),
          ),
      ],
      onChanged: disabled
          ? null
          : (value) => setState(() {
              _errorMessage = null;
              _parentId = value;
            }),
      label: 'Parent category',
      hintText: _storeId == null ? 'Select a store first' : null,
      helperText: helperText,
      icon: Icons.account_tree_outlined,
    );
  }

  Widget _buildActions({required bool editing, required bool wide}) {
    final cancelButton = IcueButton(
      label: 'Cancel',
      onPressed: _busy ? null : () => Navigator.of(context).pop(),
      variant: IcueButtonVariant.outline,
      isFullWidth: !wide,
    );
    final submitButton = IcueButton(
      label: _busy ? 'Saving…' : (editing ? 'Save changes' : 'Create category'),
      onPressed: _busy ? null : _save,
      leadingIcon: Icons.check_rounded,
      isLoading: _busy,
      isFullWidth: !wide,
    );
    final sampleButton = kDebugMode && !editing
        ? IcueButton(
            label: 'Fill sample',
            onPressed: _busy ? null : _fillSample,
            variant: IcueButtonVariant.ghost,
            leadingIcon: Icons.auto_fix_high_rounded,
          )
        : null;

    if (wide) {
      return Row(
        children: [
          ?sampleButton,
          const Spacer(),
          cancelButton,
          const SizedBox(width: 12),
          submitButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: submitButton),
          ],
        ),
        if (sampleButton != null) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: sampleButton),
        ],
      ],
    );
  }
}

const _sampleCategories = <({String name, String description})>[
  (name: 'Stationery', description: 'Paper, pens, files and office supplies.'),
  (
    name: 'Laboratory Chemicals',
    description: 'Reagents and consumables with batch and expiry dates.',
  ),
  (
    name: 'Sports Equipment',
    description: 'Balls, nets, kits and training gear.',
  ),
  (name: 'IT Hardware', description: 'Computers, projectors and peripherals.'),
  (name: 'Cleaning Supplies', description: 'Consumables for housekeeping.'),
];
