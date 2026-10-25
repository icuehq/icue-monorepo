import 'package:flutter/material.dart';

class BranchesEmptyState extends StatelessWidget {
  const BranchesEmptyState({
    required this.isFiltered,
    required this.onAction,
    this.searchQuery = '',
    super.key,
  });

  final bool isFiltered;
  final String searchQuery;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFiltered
                    ? Colors.amber.shade50
                    : primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.domain_disabled_rounded,
                size: 48,
                color: isFiltered ? Colors.amber.shade800 : primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered ? 'No matching branches' : 'No branches found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                isFiltered
                    ? 'No branches matched "$searchQuery". Check the spelling or try searching with a different term.'
                    : 'We could not find any branches assigned to your zone. Tap retry to check again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
              )
            else
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
