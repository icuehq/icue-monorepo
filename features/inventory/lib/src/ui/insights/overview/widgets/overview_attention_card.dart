import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';

/// Card listing stock and workflow alerts requiring immediate attention.
class OverviewAttentionCard extends StatelessWidget {
  const OverviewAttentionCard({required this.stats, super.key});

  final Map<String, num?> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    const warning = Color(0xFFD97706);

    final items = <(String, String, String, int, IconData, Color)>[
      for (final (key, title, subtitle, route, icon, color) in [
        (
          'out',
          'Out-of-stock lines',
          'Zero units currently available',
          InventoryRoutes.inventoryStock,
          Icons.remove_shopping_cart_outlined,
          danger,
        ),
        (
          'expired',
          'Expired stock lines',
          'Past earliest expiry date',
          InventoryRoutes.inventoryStock,
          Icons.event_busy_outlined,
          danger,
        ),
        (
          'low',
          'Low-stock lines',
          'Below reorder threshold',
          InventoryRoutes.inventoryStock,
          Icons.trending_down_rounded,
          warning,
        ),
        (
          'expiring',
          'Expiring within 30 days',
          'Review upcoming batch expiry',
          InventoryRoutes.inventoryStock,
          Icons.schedule_rounded,
          warning,
        ),
        (
          'approvals',
          'Pending approvals',
          'Issue requests awaiting review',
          InventoryRoutes.inventoryRequests,
          Icons.approval_outlined,
          warning,
        ),
        (
          'maint',
          'Assets in maintenance',
          'Currently under repair or service',
          InventoryRoutes.inventoryMaintenance,
          Icons.build_outlined,
          const Color(0xFFEA580C),
        ),
      ])
        if ((stats[key] ?? 0) > 0)
          (route, title, subtitle, stats[key]!.round(), icon, color),
    ];

    final hasIssues = items.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasIssues
              ? warning.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (hasIssues ? warning : Colors.green).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasIssues
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    size: 19,
                    color: hasIssues ? warning : Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs attention',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasIssues
                            ? '${items.length} active alert${items.length == 1 ? '' : 's'} to resolve'
                            : 'Stock & workflow health',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasIssues)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          if (!hasIssues)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All clear — nothing needs attention',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No out-of-stock, expired, or pending approval alerts.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.30,
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go(items[index].$1),
                  hoverColor: items[index].$6.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: items[index].$6.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            items[index].$5,
                            size: 17,
                            color: items[index].$6,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                items[index].$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: items[index].$6.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${items[index].$4}',
                            style: TextStyle(
                              color: items[index].$6,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
