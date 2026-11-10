import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';

/// Where every physical copy stands: a segmented bar with a legend.
class OverviewCollectionCard extends StatelessWidget {
  const OverviewCollectionCard({required this.stats, super.key});

  final Map<String, num?> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (stats['copies'] ?? 0).round();

    final known = <(String, int, Color)>[
      ('Available', (stats['available'] ?? 0).round(), Colors.green.shade600),
      ('On loan', (stats['issued'] ?? 0).round(), theme.colorScheme.primary),
      ('Damaged', (stats['damaged'] ?? 0).round(), Colors.orange.shade700),
      ('Lost', (stats['lost'] ?? 0).round(), theme.colorScheme.error),
    ];
    final other =
        total - known.fold<int>(0, (sum, segment) => sum + segment.$2);
    final segments = [
      ...known,
      if (other > 0) ('Other', other, theme.colorScheme.outline),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.go(LibraryRoutes.libraryCatalogue),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$total ${total == 1 ? 'copy' : 'copies'} in total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: total == 0
                      ? ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                        )
                      : Row(
                          spacing: 2,
                          children: [
                            for (final (_, count, color) in segments)
                              if (count > 0)
                                Expanded(
                                  flex: count,
                                  child: ColoredBox(color: color),
                                ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final (label, count, color) in segments)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          total == 0
                              ? '$count'
                              : '$count · ${(count / total * 100).round()}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
