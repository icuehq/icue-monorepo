import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Available date range presets for library reports.
enum LibraryDatePreset {
  currentMonth('Current Month'),
  lastMonth('Last Month'),
  last6Months('Last 6 Months'),
  last12Months('Last 12 Months'),
  custom('Custom Date Range');

  const LibraryDatePreset(this.label);
  final String label;
}

/// Computes the [DateTimeRange] for a given [LibraryDatePreset].
DateTimeRange calculateRangeForPreset(
  LibraryDatePreset preset, {
  DateTimeRange? customRange,
}) {
  final today = DateTime.now().dateOnly;
  switch (preset) {
    case LibraryDatePreset.currentMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    case LibraryDatePreset.lastMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      );
    case LibraryDatePreset.last6Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: today,
      );
    case LibraryDatePreset.last12Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 11),
        end: today,
      );
    case LibraryDatePreset.custom:
      return customRange ??
          DateTimeRange(start: DateTime(today.year, today.month), end: today);
  }
}
