import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/ui/widgets/voucher_details_dialog.dart';
import 'package:parent_l10n/parent_l10n.dart';

class VoucherPurchaseCard extends StatelessWidget {
  const VoucherPurchaseCard({required this.purchase, super.key});

  final VoucherPurchase purchase;

  static (Color, IconData) _style(String status) => switch (status) {
    'Completed' => (Colors.green.shade700, Icons.check_circle),
    'Initiated' => (Colors.orange.shade800, Icons.hourglass_empty),
    'Failed' => (Colors.red.shade800, Icons.error),
    _ => (Colors.black, Icons.error),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final (color, icon) = _style(purchase.status);
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text(
          purchase.personName,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${purchase.paymentDate} ${purchase.paymentTime}',
            style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            Text(
              purchase.amount.toRupees(),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IcueStatusPill(
              label: purchase.status,
              color: color,
              icon: icon,
              bordered: false,
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            spacing: 4,
            children: [
              Icon(
                Icons.credit_card_outlined,
                size: 16,
                color: Colors.grey.shade700,
              ),
              Text('${l10n.paymentModeLabel}: ', style: text.bodySmall),
              Text(
                purchase.paymentMode,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.purchasedVouchers, style: text.titleSmall),
              if (purchase.isCompleted)
                IcueButton(
                  label: l10n.detailsUpper,
                  variant: IcueButtonVariant.ghost,
                  size: IcueButtonSize.small,
                  onPressed: () => showVoucherDetails(context, purchase.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (purchase.lines.isEmpty)
            Text(l10n.noItemDetails)
          else
            for (final line in purchase.lines)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  spacing: 10,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name, style: text.labelLarge),
                            Text(
                              l10n.daysAtPrice(
                                line.days,
                                line.price.toRupees(),
                              ),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          line.amount.toRupees(),
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.convenienceFee, style: text.labelLarge),
                        Text(
                          purchase.convenienceFee.toRupees(),
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
