import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';

/// Single metric figure tile on the Library overview.
class OverviewKpiCard extends StatelessWidget {
  const OverviewKpiCard({
    required this.statKey,
    required this.value,
    required this.icon,
    this.targetRoute,
    super.key,
  });

  final String statKey;
  final num value;
  final IconData icon;
  final String? targetRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = libraryDashboardStats
        .firstWhere((stat) => stat.$1 == statKey)
        .$2;
    final warn = value > 0 && (statKey == 'overdue' || statKey == 'fines');
    final activeColor = warn
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: warn
                ? theme.colorScheme.error.withValues(alpha: 0.35)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: targetRoute == null ? null : () => context.go(targetRoute!),
            hoverColor: activeColor.withValues(alpha: 0.04),
            splashColor: activeColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 22, color: activeColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statKey == 'fines'
                              ? value.toRupees()
                              : '${value.round()}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: warn ? theme.colorScheme.error : null,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (targetRoute != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
