import 'package:flutter/material.dart';
import 'package:icue_ui/src/utils/icue_date_time_formatting.dart';
import 'package:icue_ui/src/widgets/icue_toast.dart';

/// Chip that shows a date range and opens a picker limited to [maxDays] days
/// (ending today at the latest) when tapped; [onPicked] gets the new range.
class IcueDateRangeChip extends StatelessWidget {
  const IcueDateRangeChip({
    required this.range,
    required this.emptyLabel,
    required this.tooLongMessage,
    required this.onPicked,
    this.maxDays = 10,
    super.key,
  });

  final DateTimeRange? range;

  /// Text shown while no range is chosen.
  final String emptyLabel;

  /// Toast shown when the chosen range exceeds [maxDays].
  final String tooLongMessage;
  final ValueChanged<DateTimeRange> onPicked;
  final int maxDays;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: range,
      selectableDayPredicate: (day, start, end) => start == null || end != null
          ? true
          : day.difference(start).inDays.abs() < maxDays,
    );
    if (picked == null || !context.mounted) return;
    if (picked.duration.inDays + 1 > maxDays) {
      IcueToast.warning(context, tooLongMessage);
      return;
    }
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = range;
    return ActionChip(
      avatar: const Icon(Icons.date_range, size: 18),
      label: Text(
        current == null
            ? emptyLabel
            : '${current.start.toNumericDate()} - ${current.end.toNumericDate()}',
      ),
      onPressed: () => _pick(context),
    );
  }
}
