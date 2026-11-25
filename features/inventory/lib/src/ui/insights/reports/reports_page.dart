import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/insights/reports/widgets/report_catalogue_card.dart';

/// The list of inventory reports; each opens with its own filters and CSV download.
class InventoryReportsPage extends StatelessWidget {
  const InventoryReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports')),
    body: IcueCenteredBody(
      maxWidth: double.infinity,
      child: ListView(
        padding: EdgeInsets.all(context.isWide ? 24 : 16),
        children: [
          _ResponsiveReportGrid(
            reports: InventoryReport.values,
            onOpen: (report) =>
                context.push(InventoryRoutes.inventoryReport, extra: report),
          ),
        ],
      ),
    ),
  );
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
