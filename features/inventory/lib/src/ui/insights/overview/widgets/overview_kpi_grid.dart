import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Headline figures of the Inventory overview, two per row on phones up to five on desktop.
class OverviewKpiGrid extends StatelessWidget {
  const OverviewKpiGrid({required this.stats, this.storeName, super.key});

  final Map<String, num?> stats;
  final String? storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maintenanceCount = (stats['maint'] ?? 0).round();
    final openPurchaseRequests = (stats['prs'] ?? 0).round();
    final lowCount = (stats['low'] ?? 0).round();
    final stockScope = storeName ?? 'All stores';

    final tiles = <(String, String, IconData, String, String, Color, Color?)>[
      (
        'items',
        'Active items',
        Icons.category_outlined,
        InventoryRoutes.inventoryItems,
        'Branch catalogue',
        theme.colorScheme.primary,
        null,
      ),
      (
        'available',
        'Available stock',
        Icons.inventory_2_outlined,
        InventoryRoutes.inventoryStock,
        lowCount > 0 ? '$stockScope · $lowCount low' : stockScope,
        const Color(0xFF0D9488),
        lowCount > 0 ? const Color(0xFFD97706) : null,
      ),
      (
        'value',
        'Stock value',
        Icons.currency_rupee_rounded,
        InventoryRoutes.inventoryStock,
        stockScope,
        const Color(0xFF4F46E5),
        null,
      ),
      (
        'prs',
        'Open purchase requests',
        Icons.request_quote_outlined,
        InventoryRoutes.inventoryPurchaseRequests,
        openPurchaseRequests > 0 ? 'Awaiting receipt' : 'None open',
        const Color(0xFFD97706),
        openPurchaseRequests > 0 ? const Color(0xFFD97706) : Colors.green,
      ),
      (
        'assets',
        'Registered assets',
        Icons.devices_other_outlined,
        InventoryRoutes.inventoryAssets,
        maintenanceCount > 0
            ? '$maintenanceCount in maintenance'
            : 'Active registry',
        const Color(0xFF0284C7),
        maintenanceCount > 0 ? const Color(0xFFEA580C) : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = (constraints.maxWidth / 170).floor().clamp(2, 5);
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (key, label, icon, route, caption, accent, dotColor)
                in tiles)
              if (stats[key] != null)
                _OverviewKpiCard(
                  label: label,
                  value: switch (key) {
                    'value' => stats[key]!.toRupees(),
                    'available' => stats[key]!.toQuantityText(),
                    _ => '${stats[key]!.round()}',
                  },
                  icon: icon,
                  caption: caption,
                  route: route,
                  accent: accent,
                  dotColor: dotColor ?? accent,
                  width: width,
                ),
          ],
        );
      },
    );
  }
}

class _OverviewKpiCard extends StatefulWidget {
  const _OverviewKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.caption,
    required this.route,
    required this.accent,
    required this.dotColor,
    required this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final String caption;
  final String route;
  final Color accent;
  final Color dotColor;
  final double width;

  @override
  State<_OverviewKpiCard> createState() => _OverviewKpiCardState();
}

class _OverviewKpiCardState extends State<_OverviewKpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final tintSurface = Color.alphaBlend(
      widget.accent.withValues(alpha: _hovered ? 0.06 : 0.028),
      surface,
    );

    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [surface, tintSurface],
            ),
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.42)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? widget.accent.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovered ? 16 : 10,
                offset: Offset(0, _hovered ? 5 : 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go(widget.route),
              hoverColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.accent.withValues(alpha: 0.16),
                                widget.accent.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 16,
                            color: widget.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.dotColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: _hovered
                              ? widget.accent
                              : theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.40,
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
      ),
    );
  }
}
