import 'package:flutter/material.dart';

class ReservationInitialEmptyState extends StatelessWidget {
  const ReservationInitialEmptyState({
    super.key,
    required this.status,
    required this.onReserve,
  });

  final String status;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWaiting = status == 'waiting';

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
                Icons.bookmark_outline_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isWaiting ? 'No waiting reservations' : 'No $status reservations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isWaiting
                  ? 'Reserve books on loan for students or teachers to put them in line.'
                  : 'There are currently no reservations with this status.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onReserve,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Place reservation'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationNoResultsState extends StatelessWidget {
  const ReservationNoResultsState({
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
              'No reservations match "$searchQuery"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by another title, member name, or reservation number.',
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
