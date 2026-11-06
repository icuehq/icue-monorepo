import 'package:flutter/material.dart';

class MemberInitialEmptyState extends StatelessWidget {
  const MemberInitialEmptyState({super.key, required this.memberType});

  final String memberType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = memberType == 'student';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isStudent
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isStudent
                  ? 'No student borrowers yet'
                  : 'No teacher borrowers yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Members are enrolled automatically when they first borrow or reserve a book from the circulation desk.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberNoResultsState extends StatelessWidget {
  const MemberNoResultsState({
    super.key,
    required this.searchQuery,
    required this.onClear,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No members match "$searchQuery"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by another name, ERP ID, or class number.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}
