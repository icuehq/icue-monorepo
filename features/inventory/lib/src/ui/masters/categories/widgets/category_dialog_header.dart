import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Header row for [CategoryDialog]: icon badge, title, optional inactive badge, and subtitle.
class CategoryDialogHeader extends StatelessWidget {
  const CategoryDialogHeader({
    required this.editing,
    required this.isSubcategory,
    required this.inactive,
    this.parentName,
    super.key,
  });

  final bool editing;
  final bool isSubcategory;
  final bool inactive;
  final String? parentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = editing
        ? 'Edit Category'
        : (isSubcategory ? 'New Subcategory' : 'New Category');
    final subtitle = isSubcategory
        ? 'Group items under ${parentName ?? 'a category'}.'
        : 'Group items and choose who can request and approve them.';

    return Row(
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
            isSubcategory
                ? Icons.subdirectory_arrow_right_rounded
                : Icons.account_tree_outlined,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (inactive) const IcueInactiveBadge(),
                ],
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
    );
  }
}
