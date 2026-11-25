import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

/// Icon and accent colour of each [InventoryReport] card.
extension InventoryReportCatalogueDetails on InventoryReport {
  IconData get icon => switch (this) {
    InventoryReport.currentStock => Icons.inventory_2_outlined,
    InventoryReport.expiringItems => Icons.event_busy_outlined,
    InventoryReport.stockSummary => Icons.summarize_outlined,
    InventoryReport.itemsGivenOut => Icons.outbox_outlined,
    InventoryReport.stockInOut => Icons.swap_vert_rounded,
  };

  Color get accent => switch (this) {
    InventoryReport.currentStock => const Color(0xFF0D9488),
    InventoryReport.expiringItems => const Color(0xFFDC2626),
    InventoryReport.stockSummary => const Color(0xFF4F46E5),
    InventoryReport.itemsGivenOut => const Color(0xFFD97706),
    InventoryReport.stockInOut => const Color(0xFF0284C7),
  };
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
                                : Icons.today_outlined,
                            label: hasDates ? 'Choose a period' : 'As of today',
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
