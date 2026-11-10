import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart'
    show Timestamp, dayTimestamp, readNumber;
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

class _KpiMetric {
  const _KpiMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.badge,
    this.isAlert = false,
    this.isSuccess = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? badge;
  final bool isAlert;
  final bool isSuccess;
}

/// Executive KPI cards summarizing current library report data.
class LibraryReportKpis extends StatelessWidget {
  const LibraryReportKpis({required this.kind, required this.rows, super.key});

  final LibraryReportKind kind;
  final List<Map<String, dynamic>> rows;

  List<_KpiMetric> _metricsForLoans() {
    final today = dayTimestamp(todayIST());
    final total = rows.length;
    var activeCount = 0;
    var returnedCount = 0;
    var overdueOrLostCount = 0;

    for (final row in rows) {
      final status = row['status'];
      if (status == 'returned') {
        returnedCount++;
      } else if (status == 'active') {
        activeCount++;
        final dueDate = row['dueDate'];
        if (dueDate is Timestamp && dueDate.compareTo(today) < 0) {
          overdueOrLostCount++;
        }
      } else if (status == 'lost') {
        overdueOrLostCount++;
      }
    }

    final returnRate = total == 0 ? 0 : (returnedCount / total * 100).round();

    return [
      _KpiMetric(
        label: 'Total Issues',
        value: total.toString(),
        icon: Icons.auto_stories_outlined,
        badge: 'In selected period',
      ),
      _KpiMetric(
        label: 'Returned Books',
        value: returnedCount.toString(),
        icon: Icons.check_circle_outline_rounded,
        badge: '$returnRate% return rate',
        isSuccess: returnRate >= 70,
      ),
      _KpiMetric(
        label: 'Currently Active',
        value: activeCount.toString(),
        icon: Icons.menu_book_rounded,
        badge: 'With borrowers',
      ),
      _KpiMetric(
        label: 'Overdue / Lost',
        value: overdueOrLostCount.toString(),
        icon: Icons.warning_amber_rounded,
        badge: overdueOrLostCount > 0 ? 'Requires action' : 'None overdue',
        isAlert: overdueOrLostCount > 0,
      ),
    ];
  }

  List<_KpiMetric> _metricsForMonthly() {
    var totalIssued = 0;
    var totalReturned = 0;
    var maxIssued = -1;
    var peakMonth = '—';

    for (final row in rows) {
      final issued = readNumber(row['issued']).toInt();
      final returned = readNumber(row['returned']).toInt();
      totalIssued += issued;
      totalReturned += returned;

      if (issued > maxIssued) {
        maxIssued = issued;
        peakMonth = row['month']?.toString() ?? '—';
      }
    }

    final returnRate = totalIssued == 0
        ? 0
        : (totalReturned / totalIssued * 100).round();

    return [
      _KpiMetric(
        label: 'Total Issued',
        value: totalIssued.toString(),
        icon: Icons.outbox_rounded,
        badge: '${rows.length} months tracked',
      ),
      _KpiMetric(
        label: 'Total Returned',
        value: totalReturned.toString(),
        icon: Icons.move_to_inbox_rounded,
        badge: '$returnRate% return rate',
        isSuccess: returnRate >= 70,
      ),
      _KpiMetric(
        label: 'Circulation Turnover',
        value: '$returnRate%',
        icon: Icons.loop_rounded,
        badge: 'Return clearance',
      ),
      _KpiMetric(
        label: 'Peak Month',
        value: peakMonth,
        icon: Icons.trending_up_rounded,
        badge: maxIssued > 0 ? '$maxIssued issues' : 'No data',
      ),
    ];
  }

  List<_KpiMetric> _metricsForMembers(String memberLabel) {
    final totalMembers = rows.length;
    var totalIssued = 0;
    var totalActive = 0;
    var totalOverdue = 0;

    for (final row in rows) {
      totalIssued += readNumber(row['issued']).toInt();
      totalActive += readNumber(row['active']).toInt();
      totalOverdue += readNumber(row['overdue']).toInt();
    }

    return [
      _KpiMetric(
        label: 'Active $memberLabel Borrowers',
        value: totalMembers.toString(),
        icon: Icons.people_outline_rounded,
        badge: 'With borrowing records',
      ),
      _KpiMetric(
        label: 'Total Books Issued',
        value: totalIssued.toString(),
        icon: Icons.library_books_rounded,
        badge: 'Total loans in period',
      ),
      _KpiMetric(
        label: 'Books in Hand',
        value: totalActive.toString(),
        icon: Icons.bookmark_border_rounded,
        badge: 'Currently borrowed',
      ),
      _KpiMetric(
        label: 'Overdue Books',
        value: totalOverdue.toString(),
        icon: Icons.event_busy_rounded,
        badge: totalOverdue > 0 ? 'Urgent notice needed' : 'All clear',
        isAlert: totalOverdue > 0,
      ),
    ];
  }

  Widget _buildCard(BuildContext context, _KpiMetric metric) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color iconBgColor;
    Color iconColor;
    Color? borderColor;

    if (metric.isAlert) {
      iconBgColor = colorScheme.errorContainer.withValues(alpha: 0.5);
      iconColor = colorScheme.error;
      borderColor = colorScheme.error.withValues(alpha: 0.4);
    } else if (metric.isSuccess) {
      iconBgColor = Colors.green.withValues(alpha: 0.12);
      iconColor = Colors.green.shade700;
    } else {
      iconBgColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
      iconColor = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(metric.icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: metric.isAlert ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
          if (metric.badge != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (metric.isAlert) ...[
                  Icon(Icons.error_outline, size: 13, color: colorScheme.error),
                  const SizedBox(width: 4),
                ],
                Text(
                  metric.badge!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: metric.isAlert
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: metric.isAlert
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = switch (kind) {
      LibraryReportKind.loans => _metricsForLoans(),
      LibraryReportKind.monthly => _metricsForMonthly(),
      LibraryReportKind.student => _metricsForMembers('Student'),
      LibraryReportKind.staff => _metricsForMembers('Staff'),
    };

    if (context.isWide) {
      return Row(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0) const SizedBox(width: 14),
            Expanded(child: _buildCard(context, metrics[index])),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: constraints.maxWidth < 450
                    ? constraints.maxWidth
                    : halfWidth,
                child: _buildCard(context, metric),
              ),
          ],
        );
      },
    );
  }
}
