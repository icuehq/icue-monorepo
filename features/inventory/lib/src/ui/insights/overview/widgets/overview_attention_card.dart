import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';

/// Card listing stock and workflow issues requiring immediate attention.
class OverviewAttentionCard extends StatelessWidget {
  const OverviewAttentionCard({required this.stats, super.key});

  final Map<String, num?> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final warning = Colors.amber.shade800;

    // Figures a role may not see are null and left out, as are zero counts.
    final items = <(String, String, IconData, Color)>[
      for (final (key, one, many, route, icon, color) in [
        (
          'out',
          'out-of-stock line',
          'out-of-stock lines',
          InventoryRoutes.inventoryStock,
          Icons.remove_shopping_cart_outlined,
          danger,
        ),
        (
          'expired',
          'expired line',
          'expired lines',
          InventoryRoutes.inventoryStock,
          Icons.event_busy_outlined,
          danger,
        ),
        (
          'low',
          'low-stock line',
          'low-stock lines',
          InventoryRoutes.inventoryStock,
          Icons.trending_down_rounded,
          warning,
        ),
        (
          'expiring',
          'line expiring in 30 days',
          'lines expiring in 30 days',
          InventoryRoutes.inventoryStock,
          Icons.schedule_rounded,
          warning,
        ),
        (
          'approvals',
          'pending approval',
          'pending approvals',
          InventoryRoutes.inventoryPurchaseRequests,
          Icons.approval_outlined,
          warning,
        ),
        (
          'maint',
          'asset under maintenance',
          'assets under maintenance',
          InventoryRoutes.inventoryMaintenance,
          Icons.build_outlined,
          Colors.orange.shade800,
        ),
      ])
        if ((stats[key] ?? 0) > 0)
          (
            route,
            '${stats[key]!.round()} ${stats[key]!.round() == 1 ? one : many}',
            icon,
            color,
          ),
    ];
    final hasIssues = items.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasIssues
              ? Colors.amber.shade300
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (hasIssues ? Colors.amber : Colors.green).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasIssues
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: hasIssues
                        ? Colors.amber.shade800
                        : Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Needs attention',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hasIssues)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!hasIssues)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 20,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'All clear — nothing needs attention',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.35,
                    ),
                  ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go(items[i].$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: items[i].$4.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            items[i].$3,
                            size: 16,
                            color: items[i].$4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            items[i].$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
