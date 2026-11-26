import 'package:flutter/material.dart';
import 'package:mess_meals/src/models/voucher_date_rules.dart';
import 'package:parent_l10n/parent_l10n.dart';

/// Explains the purchase cutoff and whether today/tomorrow are still open.
class PurchaseTimingBanner extends StatelessWidget {
  const PurchaseTimingBanner({required this.rules, super.key});

  final VoucherDateRules rules;

  @override
  Widget build(BuildContext context) {
    final cutoff = rules.cutoffTime;
    if (rules.mode == CutoffMode.none || cutoff == null) {
      return const SizedBox.shrink();
    }
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: cutoff ~/ 60, minute: cutoff % 60));

    final messages = switch (rules.mode) {
      CutoffMode.sameDay => [
        if (rules.isTodayClosed)
          (Icons.lock_clock_outlined, true, l10n.todayClosedAt(time))
        else
          (Icons.schedule_rounded, false, l10n.todayBuyUntil(time)),
      ],
      CutoffMode.dayBefore => [
        (Icons.lock_outline_rounded, true, l10n.todayHadToBuy(time)),
        if (rules.isTomorrowClosed)
          (Icons.lock_clock_outlined, true, l10n.tomorrowClosedAt(time))
        else
          (Icons.schedule_rounded, false, l10n.tomorrowBuyUntil(time)),
      ],
      CutoffMode.none => <(IconData, bool, String)>[],
    };

    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(Icons.alarm_rounded, size: 16, color: primary),
              Text(
                l10n.purchaseTimings,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          for (final (icon, closed, text) in messages)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: closed ? theme.colorScheme.error : primary,
                ),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: closed
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
