import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/routing/mess_meals_router.dart';
import 'package:mess_meals/src/ui/widgets/select_voucher_dates_dialog.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Pick vouchers and the days each is for, then continue to the summary.
class SelectMealVouchersPage extends StatefulWidget {
  const SelectMealVouchersPage({super.key});

  @override
  State<SelectMealVouchersPage> createState() => _SelectMealVouchersPageState();
}

class _SelectMealVouchersPageState extends State<SelectMealVouchersPage> {
  final Map<String, List<DateTime>> _dates = {};

  num _total(List<MealVoucher> vouchers) =>
      MealSelection(_dates).totalFor(vouchers);

  Future<void> _toggle(MealVoucher voucher, bool? checked) async {
    final l10n = ParentLocalizations.of(context);
    final meals = context.read<MealsProvider>();
    if (checked != true) {
      setState(() => _dates.remove(voucher.id));
      return;
    }
    // One voucher per meal type: lunch cannot be bought twice for one day.
    final taken = {
      for (final entry in _dates.entries)
        for (final v in meals.buyableVouchers.where((v) => v.id == entry.key))
          ...v.types,
    };
    if (voucher.types.any(taken.contains)) {
      IcueToast.error(
        context,
        l10n.onlyOneVoucherOfType(voucher.types.join(', ')),
      );
      return;
    }
    final rules = meals.rulesFor(voucher);
    if (rules == null) return;
    final picked = await showSelectVoucherDatesDialog(
      context,
      voucher: voucher,
      rules: rules,
      initial: _dates[voucher.id] ?? [rules.minDate],
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _dates[voucher.id] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final meals = context.watch<MealsProvider>();
    final vouchers = meals.buyableVouchers;
    final hasSelection = _dates.isNotEmpty;
    final total = _total(vouchers);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.selectMealVouchers),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: IcueButton(
          label: hasSelection
              ? l10n.continueLabel
              : l10n.selectVouchersToContinue,
          isFullWidth: true,
          size: IcueButtonSize.large,
          onPressed: hasSelection
              ? () => context.push(
                  MessMealsRoutes.summaryPath,
                  extra: MealSelection(_dates),
                )
              : null,
        ),
      ),
      body: IcueSheetBody(
        child: Column(
          children: [
            if (hasSelection)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.vouchersSelected(_dates.length),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      l10n.totalWithAmount(total.toRupees()),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vouchers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final voucher = vouchers[index];
                  return _VoucherCard(
                    voucher: voucher,
                    dates: _dates[voucher.id],
                    onChanged: (v) => _toggle(voucher, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.dates,
    required this.onChanged,
  });

  final MealVoucher voucher;
  final List<DateTime>? dates;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = dates != null;
    final sorted = [...?dates]..sort();
    final format = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: selected ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Checkbox(value: selected, onChanged: onChanged),
                Expanded(
                  child: Text(
                    voucher.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(l10n.pricePerDay(voucher.price.toRupees())),
              ],
            ),
            if (selected) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final d in sorted) Chip(label: Text(format.format(d))),
                ],
              ),
              Text(
                l10n.totalWithAmount(
                  (voucher.price * sorted.length).toRupees(),
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
