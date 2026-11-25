import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/insights/reports/widgets/report_catalogue_card.dart';

/// The report catalogue: searchable, grouped by operational area and responsive across mobile and desktop.
class InventoryReportsPage extends StatefulWidget {
  const InventoryReportsPage({super.key});

  @override
  State<InventoryReportsPage> createState() => _InventoryReportsPageState();
}

class _InventoryReportsPageState extends State<InventoryReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  InventoryReportArea? _selectedArea;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openReport(InventoryReport report) =>
      context.push(InventoryRoutes.inventoryReport, extra: report);

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedArea = null;
      _searchQuery = '';
    });
  }

  List<InventoryReport> _matchingReports() {
    final normalized = _searchQuery.trim().toLowerCase();
    return [
      for (final report in InventoryReport.values)
        if ((_selectedArea == null || report.area == _selectedArea) &&
            (normalized.isEmpty ||
                report.title.toLowerCase().contains(normalized) ||
                report.description.toLowerCase().contains(normalized) ||
                report.area.label.toLowerCase().contains(normalized)))
          report,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = context.isWide;
    final canvasColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLowest
        : Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.025),
            const Color(0xFFF6F7FB),
          );
    final matching = _matchingReports();
    final grouped = _selectedArea == null && _searchQuery.trim().isEmpty;

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: AppBar(title: const Text('Reports')),
      body: IcueCenteredBody(
        maxWidth: double.infinity,
        child: ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            _ReportsHeaderCard(
              totalReports: InventoryReport.values.length,
              totalAreas: InventoryReportArea.values.length,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: 14),
            _AreaFilterStrip(
              selectedArea: _selectedArea,
              onSelected: (area) => setState(() => _selectedArea = area),
            ),
            const SizedBox(height: 18),
            if (matching.isEmpty)
              IcueEmptyState.noResults(
                title: 'No matching reports',
                message:
                    'Try another keyword or clear the selected area filter.',
                actionLabel: 'Reset filters',
                onAction: _resetFilters,
              )
            else if (grouped)
              for (final area in InventoryReportArea.values) ...[
                _AreaSectionHeader(area: area),
                const SizedBox(height: 10),
                _ResponsiveReportGrid(
                  reports: area.reports,
                  onOpen: _openReport,
                ),
                const SizedBox(height: 22),
              ]
            else ...[
              Text(
                'Showing ${matching.length} of ${InventoryReport.values.length} reports',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _ResponsiveReportGrid(reports: matching, onOpen: _openReport),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportsHeaderCard extends StatelessWidget {
  const _ReportsHeaderCard({
    required this.totalReports,
    required this.totalAreas,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final int totalReports;
  final int totalAreas;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.assessment_outlined,
            size: 22,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory reports',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalReports reports across $totalAreas operational areas · Filter & export CSV',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search reports…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: onClearSearch,
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.38,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= IcueBreakpoints.table;
        return Container(
          padding: EdgeInsets.all(horizontal ? 18 : 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: horizontal
              ? Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    SizedBox(width: 280, child: searchField),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    const SizedBox(height: 14),
                    searchField,
                  ],
                ),
        );
      },
    );
  }
}

class _AreaFilterStrip extends StatelessWidget {
  const _AreaFilterStrip({
    required this.selectedArea,
    required this.onSelected,
  });

  final InventoryReportArea? selectedArea;
  final ValueChanged<InventoryReportArea?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AreaPill(
            label: 'All (${InventoryReport.values.length})',
            selected: selectedArea == null,
            accent: theme.colorScheme.primary,
            onTap: () => onSelected(null),
          ),
          for (final area in InventoryReportArea.values) ...[
            const SizedBox(width: 8),
            _AreaPill(
              label: '${area.label} (${area.reports.length})',
              icon: area.icon,
              selected: selectedArea == area,
              accent: area.accent,
              onTap: () => onSelected(selectedArea == area ? null : area),
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaPill extends StatelessWidget {
  const _AreaPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaSectionHeader extends StatelessWidget {
  const _AreaSectionHeader({required this.area});

  final InventoryReportArea area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: area.accent.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(area.icon, size: 16, color: area.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                area.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                area.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveReportGrid extends StatelessWidget {
  const _ResponsiveReportGrid({required this.reports, required this.onOpen});

  final List<InventoryReport> reports;
  final ValueChanged<InventoryReport> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      final width = constraints.maxWidth;
      final columnCount = width >= IcueBreakpoints.twoColumns
          ? 3
          : width >= IcueBreakpoints.table
          ? 2
          : 1;

      if (columnCount == 1) {
        return Column(
          children: [
            for (var index = 0; index < reports.length; index++) ...[
              if (index > 0) const SizedBox(height: spacing),
              ReportCatalogueCard(
                report: reports[index],
                onTap: () => onOpen(reports[index]),
              ),
            ],
          ],
        );
      }

      final rowCount = (reports.length + columnCount - 1) ~/ columnCount;
      return Column(
        children: [
          for (var row = 0; row < rowCount; row++) ...[
            if (row > 0) const SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columnCount; column++) ...[
                    if (column > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: row * columnCount + column < reports.length
                          ? ReportCatalogueCard(
                              report: reports[row * columnCount + column],
                              onTap: () =>
                                  onOpen(reports[row * columnCount + column]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
