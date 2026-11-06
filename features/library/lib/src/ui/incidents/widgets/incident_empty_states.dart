import 'package:flutter/material.dart';

class IncidentInitialEmptyState extends StatelessWidget {
  const IncidentInitialEmptyState({
    super.key,
    required this.status,
    this.onReport,
  });

  final String status;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = status == 'open';

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
                Icons.report_problem_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOpen ? 'No open incidents' : 'No $status incidents',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOpen
                  ? 'Lost and damaged books reported by students, teachers or during verification appear here.'
                  : 'There are currently no incidents matching this filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onReport != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('Report incident'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IncidentNoResultsState extends StatelessWidget {
  const IncidentNoResultsState({
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
              'No incidents match "$searchQuery"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by another copy accession number, member name, or incident number.',
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
