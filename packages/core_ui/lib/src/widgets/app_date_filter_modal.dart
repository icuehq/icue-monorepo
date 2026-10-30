import 'package:flutter/material.dart';

/// Modes for filtering report / list items by temporal dimensions.
enum AppFilterMode {
  byDate('Date'),
  byMonth('Month & Year'),
  byRange('Date Range');

  const AppFilterMode(this.label);
  final String label;
}

/// Result returned from [AppDateFilterModal.show].
class AppFilterResult {
  const AppFilterResult._({
    required this.mode,
    this.date,
    this.month,
    this.year,
    this.range,
  });

  factory AppFilterResult.byDate(DateTime date) => AppFilterResult._(
        mode: AppFilterMode.byDate,
        date: date,
      );

  factory AppFilterResult.byMonth({required String month, required String year}) =>
      AppFilterResult._(
        mode: AppFilterMode.byMonth,
        month: month,
        year: year,
      );

  factory AppFilterResult.byRange(DateTimeRange range) => AppFilterResult._(
        mode: AppFilterMode.byRange,
        range: range,
      );

  final AppFilterMode mode;
  final DateTime? date;
  final String? month;
  final String? year;
  final DateTimeRange? range;

  /// Returns user-friendly summary string for the filter badge/button.
  String get displayLabel {
    switch (mode) {
      case AppFilterMode.byDate:
        final d = date ?? DateTime.now();
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      case AppFilterMode.byMonth:
        return '$month $year';
      case AppFilterMode.byRange:
        if (range == null) return 'Selected Range';
        final s = range!.start;
        final e = range!.end;
        return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
    }
  }
}

/// Bottom sheet modal enabling users to choose between Day, Month+Year, or Range filtering.
class AppDateFilterModal extends StatefulWidget {
  const AppDateFilterModal({
    super.key,
    this.initialMode = AppFilterMode.byDate,
    this.initialDate,
    this.initialMonth,
    this.initialYear,
    this.initialRange,
  });

  final AppFilterMode initialMode;
  final DateTime? initialDate;
  final String? initialMonth;
  final String? initialYear;
  final DateTimeRange? initialRange;

  static Future<AppFilterResult?> show(
    BuildContext context, {
    AppFilterMode initialMode = AppFilterMode.byDate,
    DateTime? initialDate,
    String? initialMonth,
    String? initialYear,
    DateTimeRange? initialRange,
  }) {
    return showModalBottomSheet<AppFilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AppDateFilterModal(
        initialMode: initialMode,
        initialDate: initialDate,
        initialMonth: initialMonth,
        initialYear: initialYear,
        initialRange: initialRange,
      ),
    );
  }

  @override
  State<AppDateFilterModal> createState() => _AppDateFilterModalState();
}

class _AppDateFilterModalState extends State<AppDateFilterModal> {
  late AppFilterMode _selectedMode;
  DateTime? _selectedDate;
  String? _selectedMonth;
  String? _selectedYear;
  DateTimeRange? _selectedRange;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  late final List<String> _years = List.generate(
    10,
    (index) => (DateTime.now().year - index).toString(),
  );

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedMonth = widget.initialMonth ?? _months[DateTime.now().month - 1];
    _selectedYear = widget.initialYear ?? DateTime.now().year.toString();
    _selectedRange = widget.initialRange;
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
    }
  }

  void _applyFilter() {
    AppFilterResult result;
    switch (_selectedMode) {
      case AppFilterMode.byDate:
        result = AppFilterResult.byDate(_selectedDate ?? DateTime.now());
        break;
      case AppFilterMode.byMonth:
        result = AppFilterResult.byMonth(
          month: _selectedMonth ?? _months[0],
          year: _selectedYear ?? _years[0],
        );
        break;
      case AppFilterMode.byRange:
        if (_selectedRange == null) return;
        result = AppFilterResult.byRange(_selectedRange!);
        break;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Period',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<AppFilterMode>(
              segments: AppFilterMode.values.map((mode) {
                return ButtonSegment<AppFilterMode>(
                  value: mode,
                  label: Text(mode.label, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              selected: {_selectedMode},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedMode = newSelection.first);
              },
            ),
            const SizedBox(height: 20),
            if (_selectedMode == AppFilterMode.byDate) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Selected Date'),
                subtitle: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Choose date',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickSingleDate,
              ),
            ] else if (_selectedMode == AppFilterMode.byMonth) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _months.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedMonth = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _years.map((y) {
                        return DropdownMenuItem(value: y, child: Text(y));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedYear = val),
                    ),
                  ),
                ],
              ),
            ] else if (_selectedMode == AppFilterMode.byRange) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.date_range_rounded),
                title: const Text('Date Range'),
                subtitle: Text(
                  _selectedRange != null
                      ? '${_selectedRange!.start.day}/${_selectedRange!.start.month}/${_selectedRange!.start.year} - ${_selectedRange!.end.day}/${_selectedRange!.end.month}/${_selectedRange!.end.year}'
                      : 'Tap to select range',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickDateRange,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedMode == AppFilterMode.byRange && _selectedRange == null)
                  ? null
                  : _applyFilter,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
