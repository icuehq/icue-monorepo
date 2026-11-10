import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';

/// Modes for filtering report / list items by temporal dimensions.
enum IcueFilterMode {
  byDate('Date'),
  byMonth('Month & Year'),
  byRange('Date Range');

  const IcueFilterMode(this.label);
  final String label;
}

/// Result returned from [IcueDateFilterModal.show].
class IcueFilterResult {
  const IcueFilterResult._({
    required this.mode,
    this.date,
    this.month,
    this.year,
    this.range,
  });

  factory IcueFilterResult.byDate(DateTime date) =>
      IcueFilterResult._(mode: IcueFilterMode.byDate, date: date);

  factory IcueFilterResult.byMonth({
    required String month,
    required String year,
  }) => IcueFilterResult._(
    mode: IcueFilterMode.byMonth,
    month: month,
    year: year,
  );

  factory IcueFilterResult.byRange(DateTimeRange range) =>
      IcueFilterResult._(mode: IcueFilterMode.byRange, range: range);

  final IcueFilterMode mode;
  final DateTime? date;
  final String? month;
  final String? year;
  final DateTimeRange? range;

  /// Returns user-friendly summary string for the filter badge/button.
  String get displayLabel {
    switch (mode) {
      case IcueFilterMode.byDate:
        final d = date ?? DateTime.now();
        return d.toNumericDate();
      case IcueFilterMode.byMonth:
        return '$month $year';
      case IcueFilterMode.byRange:
        if (range == null) return 'Selected Range';
        final s = range!.start;
        final e = range!.end;
        return '${s.toNumericDate()} - ${e.toNumericDate()}';
    }
  }
}

/// Bottom sheet modal enabling users to choose between Day, Month+Year, or Range filtering.
class IcueDateFilterModal extends StatefulWidget {
  const IcueDateFilterModal({
    super.key,
    this.initialMode = IcueFilterMode.byDate,
    this.initialDate,
    this.initialMonth,
    this.initialYear,
    this.initialRange,
  });

  final IcueFilterMode initialMode;
  final DateTime? initialDate;
  final String? initialMonth;
  final String? initialYear;
  final DateTimeRange? initialRange;

  static Future<IcueFilterResult?> show(
    BuildContext context, {
    IcueFilterMode initialMode = IcueFilterMode.byDate,
    DateTime? initialDate,
    String? initialMonth,
    String? initialYear,
    DateTimeRange? initialRange,
  }) {
    return showModalBottomSheet<IcueFilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IcueDateFilterModal(
        initialMode: initialMode,
        initialDate: initialDate,
        initialMonth: initialMonth,
        initialYear: initialYear,
        initialRange: initialRange,
      ),
    );
  }

  @override
  State<IcueDateFilterModal> createState() => _AppDateFilterModalState();
}

class _AppDateFilterModalState extends State<IcueDateFilterModal> {
  late IcueFilterMode _selectedMode;
  DateTime? _selectedDate;
  String? _selectedMonth;
  String? _selectedYear;
  DateTimeRange? _selectedRange;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
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
    // Callers may pass a numeric month ("10"); dropdown values must match
    // an item exactly, so map to a name and fall back to the current one.
    final monthIndex = int.tryParse(widget.initialMonth ?? '');
    _selectedMonth = _months.contains(widget.initialMonth)
        ? widget.initialMonth
        : (monthIndex != null && monthIndex >= 1 && monthIndex <= 12)
        ? _months[monthIndex - 1]
        : _months[DateTime.now().month - 1];
    _selectedYear = _years.contains(widget.initialYear)
        ? widget.initialYear
        : _years.first;
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
    IcueFilterResult result;
    switch (_selectedMode) {
      case IcueFilterMode.byDate:
        result = IcueFilterResult.byDate(_selectedDate ?? DateTime.now());
        break;
      case IcueFilterMode.byMonth:
        result = IcueFilterResult.byMonth(
          month: _selectedMonth ?? _months[0],
          year: _selectedYear ?? _years[0],
        );
        break;
      case IcueFilterMode.byRange:
        if (_selectedRange == null) return;
        result = IcueFilterResult.byRange(_selectedRange!);
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
            SegmentedButton<IcueFilterMode>(
              segments: IcueFilterMode.values.map((mode) {
                return ButtonSegment<IcueFilterMode>(
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
            if (_selectedMode == IcueFilterMode.byDate) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Selected Date'),
                subtitle: Text(
                  _selectedDate != null
                      ? _selectedDate!.toNumericDate()
                      : 'Choose date',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickSingleDate,
              ),
            ] else if (_selectedMode == IcueFilterMode.byMonth) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _years.map((y) {
                        return DropdownMenuItem(value: y, child: Text(y));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedYear = val),
                    ),
                  ),
                ],
              ),
            ] else if (_selectedMode == IcueFilterMode.byRange) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.date_range_rounded),
                title: const Text('Date Range'),
                subtitle: Text(
                  _selectedRange != null
                      ? '${_selectedRange!.start.toNumericDate()} - ${_selectedRange!.end.toNumericDate()}'
                      : 'Tap to select range',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickDateRange,
              ),
            ],
            const SizedBox(height: 24),
            IcueButton(
              label: 'Apply Filter',
              onPressed:
                  (_selectedMode == IcueFilterMode.byRange &&
                      _selectedRange == null)
                  ? null
                  : _applyFilter,
            ),
          ],
        ),
      ),
    );
  }
}
