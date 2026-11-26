import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Opens the day-by-day status of a completed voucher purchase.
Future<void> showVoucherDetails(BuildContext context, int voucherId) {
  context.read<MealsProvider>().loadVoucherDays(voucherId);
  return showDialog<void>(
    context: context,
    builder: (_) => const _VoucherDetailsDialog(),
  );
}

class _VoucherDetailsDialog extends StatelessWidget {
  const _VoucherDetailsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final meals = context.watch<MealsProvider>();
    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      title: Text(
        l10n.voucherDetailsTitle,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      actions: [
        IcueButton(
          label: l10n.close.toUpperCase(),
          size: IcueButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      content: SizedBox(
        width: 600,
        child: meals.loading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: meals.voucherDays.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DayCard(day: meals.voucherDays[i]),
              ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final VoucherDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final (color, label, icon) = day.isUsed
        ? (Colors.green, l10n.voucherUsed, Icons.check_circle)
        : day.isExpired
        ? (Colors.red, l10n.voucherExpired, Icons.cancel)
        : (Colors.grey, l10n.voucherUnused, Icons.check_circle_outline);
    Widget field(String name, String? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value ?? '-',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.type,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  avatar: Icon(icon, color: Colors.white, size: 20),
                  label: Text(label),
                  backgroundColor: color,
                  side: BorderSide(color: color),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                field(l10n.effectiveDateLabel, day.displayDate),
                field(l10n.expiryDateLabel, day.expiryDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
