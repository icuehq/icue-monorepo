import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/models/voucher_date_rules.dart';
import 'package:mess_meals/src/ui/widgets/purchase_timing_banner.dart';
import 'package:mess_meals/src/ui/widgets/quick_select_panel.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

/// Lets the parent pick the days of [voucher]; null when cancelled.
Future<List<DateTime>?> showSelectVoucherDatesDialog(
  BuildContext context, {
  required MealVoucher voucher,
  required VoucherDateRules rules,
  required List<DateTime> initial,
}) => showDialog<List<DateTime>>(
  context: context,
  builder: (_) => _SelectVoucherDatesDialog(
    voucher: voucher,
    rules: rules,
    initial: initial,
  ),
);

class _SelectVoucherDatesDialog extends StatefulWidget {
  const _SelectVoucherDatesDialog({
    required this.voucher,
    required this.rules,
    required this.initial,
  });

  final MealVoucher voucher;
  final VoucherDateRules rules;
  final List<DateTime> initial;

  @override
  State<_SelectVoucherDatesDialog> createState() =>
      _SelectVoucherDatesDialogState();
}

class _SelectVoucherDatesDialogState extends State<_SelectVoucherDatesDialog> {
  final _picker = DateRangePickerController();
  late final List<DateTime> _available = widget.rules.availableDates;
  List<DateTime> _selected = [];

  @override
  void initState() {
    super.initState();
    var start = widget.initial
        .map((d) => DateTime(d.year, d.month, d.day))
        .where(widget.rules.isSelectable)
        .toList();
    if (start.isEmpty && _available.isNotEmpty) start = [_available.first];
    _select(start, notify: false);
  }

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _select(List<DateTime> days, {bool notify = true}) {
    final next = days.toSet().toList()..sort();
    _selected = next;
    _picker.selectedDates = next;
    if (notify) setState(() {});
  }

  void _onCount(int count) =>
      _select(count <= 0 ? [] : _available.take(count).toList());

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rules = widget.rules;
    final range = DateFormat('d MMM');
    final width = math.min(MediaQuery.sizeOf(context).width - 24, 640.0);
    final holidayBg = scheme.errorContainer.withValues(alpha: 0.27);
    final purchasedBg = scheme.tertiaryContainer.withValues(alpha: 0.27);
    final tooMany = _selected.length > _available.length;
    final canConfirm =
        _selected.isNotEmpty && !tooMany && _available.isNotEmpty;

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      contentPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Row(
        spacing: 12,
        children: [
          Icon(Icons.calendar_month_rounded, color: scheme.primary, size: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectVoucherDates(widget.voucher.displayName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  l10n.bookableRange(
                    '${range.format(rules.minDate)} – ${range.format(rules.maxDate)}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PurchaseTimingBanner(rules: rules),
              ),
              if (_available.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: QuickSelectPanel(
                    available: _available.length,
                    onCount: _onCount,
                  ),
                ),
              if (_available.isEmpty)
                IcueEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: l10n.noBookableDates,
                  message: l10n.noBookableDatesMessage,
                  neutral: true,
                )
              else ...[
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _Legend(color: scheme.primary, label: l10n.legendSelected),
                    _Legend(color: holidayBg, label: l10n.legendHoliday),
                    _Legend(color: purchasedBg, label: l10n.legendPurchased),
                    _Legend(label: l10n.legendWeekend),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SfDateRangePicker(
                    controller: _picker,
                    selectionMode: DateRangePickerSelectionMode.multiple,
                    minDate: rules.minDate,
                    maxDate: rules.maxDate,
                    toggleDaySelection: true,
                    selectableDayPredicate: rules.isSelectable,
                    onSelectionChanged: (args) {
                      final value = args.value;
                      if (value is List<DateTime>) {
                        _select(value.where(rules.isSelectable).toList());
                      }
                    },
                    monthViewSettings: DateRangePickerMonthViewSettings(
                      blackoutDates: rules.holidays.toList(),
                      specialDates: rules.purchasedDays.toList(),
                    ),
                    selectionColor: scheme.primary,
                    selectionTextStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    todayHighlightColor: scheme.primary,
                    headerStyle: DateRangePickerHeaderStyle(
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    monthCellStyle: DateRangePickerMonthCellStyle(
                      textStyle: theme.textTheme.bodyMedium,
                      blackoutDatesDecoration: BoxDecoration(
                        color: holidayBg,
                        shape: BoxShape.circle,
                      ),
                      blackoutDateTextStyle: theme.textTheme.bodyMedium
                          ?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                      specialDatesDecoration: BoxDecoration(
                        color: purchasedBg,
                        shape: BoxShape.circle,
                      ),
                      specialDatesTextStyle: theme.textTheme.bodyMedium
                          ?.copyWith(
                            color: scheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                      disabledDatesTextStyle: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.disabledColor),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.daysSelected(_selected.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l10n.totalWithAmount(
                      (widget.voucher.price * _selected.length).toRupees(),
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () => Navigator.pop(context, _selected)
                  : null,
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, this.color});

  final String label;

  /// Null draws the outlined "disabled" swatch.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlined = color == null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: outlined
                ? Border.all(color: theme.disabledColor, width: 1.5)
                : null,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: outlined
                ? theme.disabledColor
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
