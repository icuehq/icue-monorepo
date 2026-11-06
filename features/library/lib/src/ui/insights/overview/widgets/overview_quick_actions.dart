import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';

/// Quick action buttons at the top of the Library overview.
class OverviewQuickActions extends StatelessWidget {
  const OverviewQuickActions({required this.libraryProvider, super.key});

  final LibraryProvider libraryProvider;

  @override
  Widget build(BuildContext context) {
    final access = libraryProvider.access;
    final theme = Theme.of(context);

    final actions = <(String, IconData, String, bool)>[
      if (access.can('library.circulation.operate'))
        (
          'Issue or return',
          Icons.swap_horiz_rounded,
          LibraryRoutes.libraryCirculation,
          true,
        ),
      if (access.can('library.catalogue'))
        ('Add book', Icons.add_rounded, LibraryRoutes.libraryBookForm, false),
      if (access.can('library.members.view'))
        (
          'Members',
          Icons.people_outline_rounded,
          LibraryRoutes.libraryMembers,
          false,
        ),
      if (access.can('library.reports.view'))
        (
          'Reports',
          Icons.assessment_outlined,
          LibraryRoutes.libraryReports,
          false,
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, icon, path, isPrimary) in actions)
          Material(
            color: isPrimary
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => context.go(path),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: isPrimary
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isPrimary
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
