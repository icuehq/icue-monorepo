import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// A card representing a top-level category and its nested subcategories.
class LibraryCategoryCard extends StatefulWidget {
  const LibraryCategoryCard({
    super.key,
    required this.category,
    required this.subcategories,
    required this.onViewBooks,
    required this.onEdit,
    required this.onAddSubcategory,
    required this.onToggleActive,
    this.initiallyExpanded = false,
  });

  final LibraryCategory category;
  final List<LibraryCategory> subcategories;
  final bool initiallyExpanded;
  final ValueChanged<LibraryCategory> onViewBooks;
  final ValueChanged<LibraryCategory> onEdit;
  final ValueChanged<LibraryCategory> onAddSubcategory;
  final ValueChanged<LibraryCategory> onToggleActive;

  @override
  State<LibraryCategoryCard> createState() => _LibraryCategoryCardState();
}

class _LibraryCategoryCardState extends State<LibraryCategoryCard> {
  late bool _expanded =
      widget.initiallyExpanded || widget.subcategories.length <= 4;

  @override
  void didUpdateWidget(covariant LibraryCategoryCard oldWidget) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category info
          InkWell(
            onTap: hasSubs
                ? () => setState(() => _expanded = !_expanded)
                : () => widget.onViewBooks(category),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
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
                              const IcueInactiveBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
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
                                    fontWeight: FontWeight.w600,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (category.description != null &&
                            category.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            category.description!,
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
                  if (hasSubs)
                    IconButton(
                      icon: Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                    ),
                  _buildMenu(context, category, isSub: false),
                ],
              ),
            ),
          ),

          // Subcategories list (if expanded)
          if (hasSubs && _expanded) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Container(
              color: theme.colorScheme.surfaceContainerLowest.withValues(
                alpha: 0.5,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < subs.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 44,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    InkWell(
                      onTap: () => widget.onViewBooks(subs[i]),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 9, 10, 9),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          subs[i].name,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      if (!subs[i].active) ...[
                                        const SizedBox(width: 6),
                                        const IcueInactiveBadge(),
                                      ],
                                    ],
                                  ),
                                  if (subs[i].description != null &&
                                      subs[i].description!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subs[i].description!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _buildMenu(context, subs[i], isSub: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Footer action bar
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                IcueButton(
                  label: 'View books',
                  onPressed: () => widget.onViewBooks(category),
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.menu_book_outlined,
                ),
                const Spacer(),
                IcueButton(
                  label: 'Add subcategory',
                  onPressed: () => widget.onAddSubcategory(category),
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.add_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(
    BuildContext context,
    LibraryCategory category, {
    required bool isSub,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      tooltip: 'Options',
      onSelected: (value) {
        switch (value) {
          case 'books':
            widget.onViewBooks(category);
          case 'edit':
            widget.onEdit(category);
          case 'sub':
            widget.onAddSubcategory(category);
          case 'toggle':
            widget.onToggleActive(category);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'books',
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18),
              SizedBox(width: 10),
              Text('View books'),
            ],
          ),
        ),
        ...[
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
          if (!isSub)
            const PopupMenuItem(
              value: 'sub',
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18),
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
                  category.active
                      ? Icons.block_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(category.active ? 'Deactivate' : 'Activate'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
