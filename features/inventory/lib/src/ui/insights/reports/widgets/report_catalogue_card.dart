import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

/// Operational grouping of [InventoryReport] items shown in the report catalogue.
enum InventoryReportArea {
  stock(
    'Stock & valuation',
    'Current balances, reorder thresholds and batch expiry',
    Icons.inventory_2_outlined,
    Color(0xFF0D9488),
  ),
  movements(
    'Movements',
    'Receipts, issues, consumption trends and write-offs',
    Icons.swap_horiz_rounded,
    Color(0xFF4F46E5),
  ),
  procurement(
    'Procurement',
    'Purchase request deliveries and pending receipts',
    Icons.local_shipping_outlined,
    Color(0xFFD97706),
  ),
  assets(
    'Assets & maintenance',
    'Registered asset lifecycle, holders and repair costs',
    Icons.devices_other_outlined,
    Color(0xFF0284C7),
  );

  const InventoryReportArea(this.label, this.subtitle, this.icon, this.accent);

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;

  List<InventoryReport> get reports => [
    for (final report in InventoryReport.values)
      if (report.area == this) report,
  ];
}

/// Visual metadata mapping each [InventoryReport] to its area, icon and accent colour.
extension InventoryReportCatalogueDetails on InventoryReport {
  InventoryReportArea get area => switch (this) {
    InventoryReport.stockOnHand ||
    InventoryReport.reorder ||
    InventoryReport.expiry => InventoryReportArea.stock,
    InventoryReport.consumption ||
    InventoryReport.ledger ||
    InventoryReport.losses => InventoryReportArea.movements,
    InventoryReport.purchases => InventoryReportArea.procurement,
    InventoryReport.assetRegister ||
    InventoryReport.maintenanceCost => InventoryReportArea.assets,
  };

  IconData get icon => switch (this) {
    InventoryReport.stockOnHand => Icons.inventory_2_outlined,
    InventoryReport.reorder => Icons.shopping_cart_checkout_rounded,
    InventoryReport.expiry => Icons.event_busy_outlined,
    InventoryReport.consumption => Icons.trending_up_rounded,
    InventoryReport.ledger => Icons.receipt_long_outlined,
    InventoryReport.losses => Icons.report_problem_outlined,
    InventoryReport.purchases => Icons.local_shipping_outlined,
    InventoryReport.assetRegister => Icons.devices_other_outlined,
    InventoryReport.maintenanceCost => Icons.build_outlined,
  };

  Color get accent => switch (this) {
    InventoryReport.stockOnHand => const Color(0xFF0D9488),
    InventoryReport.reorder => const Color(0xFFD97706),
    InventoryReport.expiry => const Color(0xFFDC2626),
    InventoryReport.consumption => const Color(0xFF4F46E5),
    InventoryReport.ledger => const Color(0xFF4338CA),
    InventoryReport.losses => const Color(0xFFEA580C),
    InventoryReport.purchases => const Color(0xFFD97706),
    InventoryReport.assetRegister => const Color(0xFF0284C7),
    InventoryReport.maintenanceCost => const Color(0xFF0369A1),
  };

  String get filterSummary {
    if (filters.isEmpty) return 'CSV export ready';
    final noun = this == InventoryReport.ledger ? 'movement' : 'status';
    return '${filters.length} $noun filters';
  }
}

/// A modern, hover-responsive card representing one [InventoryReport] in the catalogue.
class ReportCatalogueCard extends StatefulWidget {
  const ReportCatalogueCard({
    required this.report,
    required this.onTap,
    super.key,
  });

  final InventoryReport report;
  final VoidCallback onTap;

  @override
  State<ReportCatalogueCard> createState() => _ReportCatalogueCardState();
}

class _ReportCatalogueCardState extends State<ReportCatalogueCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = widget.report;
    final accent = report.accent;
    final hasDates = report.source.hasDates;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? accent.withValues(alpha: 0.48)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? accent.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(report.icon, size: 20, color: accent),
                          ),
                          const Spacer(),
                          _ScopePill(
                            icon: hasDates
                                ? Icons.date_range_rounded
                                : Icons.bolt_rounded,
                            label: hasDates ? 'Date period' : 'Live snapshot',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        report.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            report.filters.isEmpty
                                ? Icons.download_outlined
                                : Icons.tune_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              report.filterSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? accent.withValues(alpha: 0.14)
                                  : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _hovered
                                  ? accent
                                  : theme.colorScheme.onSurfaceVariant,
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
        ),
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
