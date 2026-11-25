import 'package:flutter/material.dart' show DateTimeRange;
import 'package:icue_ui/src/utils/icue_date_time_formatting.dart';

/// Period presets of report and list date filters.
enum IcueDatePreset {
  all('All'),
  currentMonth('Current Month'),
  lastMonth('Last Month'),
  last6Months('Last 6 Months'),
  last12Months('Last 12 Months'),
  custom('Custom Date Range');

  const IcueDatePreset(this.label);
  final String label;

  /// The days this preset covers, ending today (last month ends on its last day);
  /// [custom] is [customRange], or the current month without one.
  DateTimeRange range({DateTimeRange? customRange}) {
    final today = DateTime.now().dateOnly;
    return switch (this) {
      all => DateTimeRange(start: DateTime(2000), end: today),
      currentMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
      lastMonth => DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      ),
      last6Months => DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: today,
      ),
      last12Months => DateTimeRange(
        start: DateTime(today.year, today.month - 11),
        end: today,
      ),
      custom =>
        customRange ??
            DateTimeRange(start: DateTime(today.year, today.month), end: today),
    };
  }
}
