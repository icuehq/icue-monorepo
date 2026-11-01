import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';

class TrackingBadge extends StatelessWidget {
  const TrackingBadge({super.key, required this.tracking});

  final Tracking tracking;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (tracking) {
      Tracking.quantity => (
        Icons.format_list_numbered_rounded,
        Colors.blue.shade700,
      ),
      Tracking.batch => (Icons.layers_outlined, Colors.amber.shade800),
      Tracking.asset => (Icons.qr_code_2_rounded, Colors.purple.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            tracking.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryCodeBadge extends StatelessWidget {
  const CategoryCodeBadge({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.subcategories,
    required this.canEdit,
    required this.onViewItems,
    required this.onEdit,
    required this.onAddSubcategory,
    required this.onToggleActive,
    this.initiallyExpanded = false,
  });

  final InventoryCategory category;
  final List<InventoryCategory> subcategories;
  final bool canEdit;
  final bool initiallyExpanded;
  final ValueChanged<InventoryCategory> onViewItems;
  final ValueChanged<InventoryCategory> onEdit;
  final ValueChanged<InventoryCategory> onAddSubcategory;
  final ValueChanged<InventoryCategory> onToggleActive;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  late bool _expanded =
      widget.initiallyExpanded || widget.subcategories.length <= 3;

  @override
  void didUpdateWidget(covariant CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded &&
        widget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.category;
    final subs = widget.subcategories;
    final hasSubs = subs.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: main category
          InkWell(
            onTap: hasSubs
                ? () => setState(() => _expanded = !_expanded)
                : () => widget.onViewItems(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                category.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!category.active) ...[
                              const SizedBox(width: 8),
                              const InactiveBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CategoryCodeBadge(code: category.code),
                            TrackingBadge(tracking: category.suggestedTracking),
                            if (hasSubs)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${subs.length} ${subs.length == 1 ? 'subcategory' : 'subcategories'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (category.description != null &&
                            category.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            category.description!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasSubs)
                        IconButton(
                          icon: Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 22,
                            color: theme.colorScheme.outline,
                          ),
                          tooltip: _expanded ? 'Collapse' : 'Expand',
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                        ),
                      _CategoryMenuButton(
                        canEdit: widget.canEdit,
                        isActive: category.active,
                        isSub: false,
                        onViewItems: () => widget.onViewItems(category),
                        onEdit: () => widget.onEdit(category),
                        onAddSub: () => widget.onAddSubcategory(category),
                        onToggleActive: () => widget.onToggleActive(category),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subcategories list
          if (hasSubs && _expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            Container(
              color: theme.colorScheme.surfaceContainerLowest,
              child: Column(
                children: [
                  for (final sub in subs)
                    _SubcategoryRow(
                      subcategory: sub,
                      canEdit: widget.canEdit,
                      onViewItems: () => widget.onViewItems(sub),
                      onEdit: () => widget.onEdit(sub),
                      onToggleActive: () => widget.onToggleActive(sub),
                    ),
                  if (widget.canEdit)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => widget.onAddSubcategory(category),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add subcategory'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.subcategory,
    required this.canEdit,
    required this.onViewItems,
    required this.onEdit,
    required this.onToggleActive,
  });

  final InventoryCategory subcategory;
  final bool canEdit;
  final VoidCallback onViewItems;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = subcategory;

    return InkWell(
      onTap: onViewItems,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 14, 10),
        child: Row(
          children: [
            Icon(
              Icons.subdirectory_arrow_right_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!category.active) ...[
                        const SizedBox(width: 8),
                        const InactiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CategoryCodeBadge(code: category.code),
                      TrackingBadge(tracking: category.suggestedTracking),
                    ],
                  ),
                  if (category.description != null &&
                      category.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      category.description!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _CategoryMenuButton(
              canEdit: canEdit,
              isActive: category.active,
              isSub: true,
              onViewItems: onViewItems,
              onEdit: onEdit,
              onAddSub: null,
              onToggleActive: onToggleActive,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryMenuButton extends StatelessWidget {
  const _CategoryMenuButton({
    required this.canEdit,
    required this.isActive,
    required this.isSub,
    required this.onViewItems,
    required this.onEdit,
    required this.onAddSub,
    required this.onToggleActive,
  });

  final bool canEdit;
  final bool isActive;
  final bool isSub;
  final VoidCallback onViewItems;
  final VoidCallback onEdit;
  final VoidCallback? onAddSub;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'items':
            onViewItems();
          case 'edit':
            onEdit();
          case 'sub':
            onAddSub?.call();
          case 'toggle':
            onToggleActive();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'items',
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18),
              SizedBox(width: 10),
              Text('View items'),
            ],
          ),
        ),
        if (canEdit) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
          if (!isSub && onAddSub != null)
            const PopupMenuItem(
              value: 'sub',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Add subcategory'),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(isActive ? 'Deactivate' : 'Activate'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
