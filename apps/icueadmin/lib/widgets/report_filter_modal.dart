import 'package:flutter/material.dart';

import '../../../utils/constants.dart';
import '../utils/app_utils.dart';
import 'inputfield.dart';

/// Data returned when the user taps “Apply”.
class FilterResult {
  FilterResult.byMonth({required this.month, required this.year})
    : mode = FilterMode.bymonth,
      range = null,
      date = null;

  FilterResult.byRange(this.range)
    : mode = FilterMode.byperiod,
      month = null,
      year = null,
      date = null;

  FilterResult.bydate(this.date)
    : mode = FilterMode.bydate,
      range = null,
      month = null,
      year = null;

  final DateTime? date;
  final FilterMode mode;
  final String? month;
  final DateTimeRange? range;
  final String? year;
}

/// A modal sheet that lets the user pick either
///  • A single Date, **or**
///  • Month + Year, **or**
///  • A DateRange
/// on “Apply” it pops itself returning a [FilterResult].
class ReportFilterModal extends StatefulWidget {
  const ReportFilterModal({
    super.key,
    required this.initialMonth,
    required this.initialYear,
    required this.filterMode,
    this.initialRange,
    required this.initialDate,
  });

  final FilterMode filterMode;
  final DateTime initialDate;
  final String initialMonth;
  final DateTimeRange? initialRange;
  final String initialYear;

  @override
  State<ReportFilterModal> createState() => _ReportFilterModalState();

  /// Convenience: open the filter and await its result.
  static Future<FilterResult?> show(
    BuildContext context, {
    required String month,
    required DateTime date,
    required String year,
    required FilterMode filterMode,
    DateTimeRange? range,
  }) {
    return showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportFilterModal(
        initialDate: date,
        initialMonth: month,
        initialYear: year,
        initialRange: range,
        filterMode: filterMode,
      ),
    );
  }
}

class _ReportFilterModalState extends State<ReportFilterModal> {
  late FilterMode _mode;
  late DateTime _tempDate;
  late String _tempMonth;
  DateTimeRange? _tempRange;
  late String _tempYear;

  @override
  void initState() {
    super.initState();
    _mode = widget.filterMode;
    _tempMonth = widget.initialMonth;
    _tempYear = widget.initialYear;
    _tempRange = widget.initialRange;
    _tempDate = widget.initialDate;
  }

  bool get _canApply {
    switch (_mode) {
      case FilterMode.bydate:
        return true;
      case FilterMode.bymonth:
        return true;
      case FilterMode.byperiod:
        return _tempRange != null;
    }
  }

  String _fmt(DateTime d) => d.formattedDate();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              isSelected: [
                _mode == FilterMode.bydate,
                _mode == FilterMode.bymonth,
                _mode == FilterMode.byperiod,
              ],
              onPressed: (index) {
                setState(() {
                  _mode = FilterMode.values[index];
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('By Date'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('By Month'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('By Range'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2) Conditional inputs
            if (_mode == FilterMode.bydate) ...[
              InputField(
                initialValue: _tempDate.formattedDate(),
                key: const ValueKey('Date'),
                label: 'Date',
                showTitle: false,
                filled: false,
                hintText: 'Select Date',
                controller: TextEditingController(
                  text: _tempDate.formattedDate(),
                ),
                readOnly: true,
                type: TextFieldType.datePicker,
                onTap: () async {
                  final date = await AppUtils.selectDate(
                    context: context,
                    initialDate: _tempDate,
                  );
                  if (date != null) {
                    setState(() {
                      _tempDate = date;
                    });
                  }
                },
              ),
            ] else if (_mode == FilterMode.bymonth) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tempMonth,
                      decoration: FilterBar.decoration.copyWith(
                        labelText: 'Month',
                      ),
                      items: months
                          .map(
                            (m) => DropdownMenuItem(
                              value: m['val'],
                              child: Text(m['name']!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _tempMonth = v ?? _tempMonth),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tempYear,
                      decoration: FilterBar.decoration.copyWith(
                        labelText: 'Year',
                      ),
                      items: generateYears()
                          .map(
                            (y) => DropdownMenuItem(
                              value: y.toString(),
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _tempYear = v ?? _tempYear),
                    ),
                  ),
                ],
              ),
            ] else ...[
              GestureDetector(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange: _tempRange,
                  );
                  if (picked != null) setState(() => _tempRange = picked);
                },
                child: InputDecorator(
                  decoration: FilterBar.decoration.copyWith(
                    labelText: 'Date Range',
                  ),
                  child: Text(
                    _tempRange == null
                        ? 'Select range'
                        : '${_fmt(_tempRange!.start)} – ${_fmt(_tempRange!.end)}',
                    style: _tempRange == null
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 3) Apply button
            ElevatedButton(
              onPressed: _canApply
                  ? () {
                      late FilterResult result;
                      switch (_mode) {
                        case FilterMode.bydate:
                          result = FilterResult.bydate(_tempDate);
                          break;
                        case FilterMode.bymonth:
                          result = FilterResult.byMonth(
                            month: _tempMonth,
                            year: _tempYear,
                          );
                          break;
                        case FilterMode.byperiod:
                          result = FilterResult.byRange(_tempRange!);
                          break;
                      }
                      Navigator.pop(context, result);
                    }
                  : null,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// A public class or a top-level constant is more conventional.
class FilterBar {
  static final InputDecoration decoration = InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
  );
}
