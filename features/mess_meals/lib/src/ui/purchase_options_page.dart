import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/routing/mess_meals_router.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Buy vouchers, see past purchases, and read the school's purchase rules.
class PurchaseOptionsPage extends StatelessWidget {
  const PurchaseOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final rules = context.watch<MealsProvider>().config?.rules ?? [];
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.instantMealPurchase),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OptionCard(
              icon: Icons.local_activity_outlined,
              label: l10n.buyMealVouchers,
              onTap: () => context.push(MessMealsRoutes.selectVouchersPath),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.book_outlined,
              label: l10n.vouchersHistory,
              onTap: () => context.push(MessMealsRoutes.historyPath),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.purchaseRules,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty)
              Center(child: Text(l10n.noRules))
            else
              for (final rule in rules)
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            '${rule.position}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rule.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
