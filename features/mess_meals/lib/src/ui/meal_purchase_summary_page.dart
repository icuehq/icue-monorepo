import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/routing/mess_meals_router.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Price breakdown of the chosen vouchers, then on to the payment.
class MealPurchaseSummaryPage extends StatefulWidget {
  const MealPurchaseSummaryPage({required this.selection, super.key});

  final MealSelection selection;

  @override
  State<MealPurchaseSummaryPage> createState() =>
      _MealPurchaseSummaryPageState();
}

class _MealPurchaseSummaryPageState extends State<MealPurchaseSummaryPage> {
  num _amount = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final meals = context.read<MealsProvider>();
      _amount = widget.selection.totalFor(
        meals.config?.messConfig.vouchers ?? [],
      );
      meals.calculateCharges(_amount);
    });
  }

  Future<void> _pay() async {
    final session = await context.read<MealsProvider>().checkOut(
      widget.selection,
      _amount,
    );
    if (!mounted || session == null) return;
    await context.push(MessMealsRoutes.paymentPath, extra: session);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final meals = context.watch<MealsProvider>();
    final vouchers = meals.config?.messConfig.vouchers ?? [];
    final charges = meals.charges;
    final amount = widget.selection.totalFor(vouchers);
    final showFee =
        charges != null &&
        charges.showConvenienceFee &&
        (meals.config?.convenienceFeeEnabled ?? false);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.orderSummary),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: IcueButton(
          label: l10n.proceedToPay,
          isFullWidth: true,
          size: IcueButtonSize.large,
          onPressed: meals.loading ? null : _pay,
        ),
      ),
      body: IcueSheetBody(
        loading: meals.loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      l10n.orderSummary,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (charges != null)
                      _Row(label: l10n.subTotal, value: charges.amount),
                    if (showFee)
                      _Row(
                        label: l10n.convenienceFee,
                        value: charges.convenienceFee,
                      ),
                    const Divider(height: 24),
                    _Row(
                      label: l10n.totalAmount,
                      value: charges?.total ?? amount,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.voucherDetailsHeading,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final entry in widget.selection.datesByVoucher.entries)
              _VoucherLines(
                voucher: vouchers.where((v) => v.id == entry.key).firstOrNull,
                dates: [...entry.value]..sort(),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoucherLines extends StatelessWidget {
  const _VoucherLines({required this.voucher, required this.dates});

  final MealVoucher? voucher;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final voucher = this.voucher;
    if (voucher == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final format = DateFormat('dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher.displayName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                (voucher.price * dates.length).toRupees(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in dates)
                Chip(
                  label: Text(format.format(d)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.style});

  final String label;
  final num value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: base),
        Text(value.toRupees(), style: style ?? base),
      ],
    );
  }
}
