import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/routing/mess_meals_router.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// First page of the voucher purchase: who is buying and their mess status.
class StudentMessDetailsPage extends StatefulWidget {
  const StudentMessDetailsPage({super.key});

  @override
  State<StudentMessDetailsPage> createState() => _StudentMessDetailsPageState();
}

class _StudentMessDetailsPageState extends State<StudentMessDetailsPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<MealsProvider>().loadPurchaseData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final meals = context.watch<MealsProvider>();
    final student = context.watch<ParentAuthProvider>().selectedStudent;
    final annual = meals.studentConfig?.isAnnualMessOpted ?? false;
    final initials =
        student?.name
            .split(' ')
            .map((e) => e.isEmpty ? '' : e[0])
            .take(2)
            .join() ??
        '';
    // An annual subscriber with nothing left to buy has no next step.
    final canContinue = !(annual && meals.buyableVouchers.isEmpty);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.instantMealPurchase),
        centerTitle: true,
        bottom: IcueContextBar(label: student?.name),
      ),
      bottomNavigationBar: canContinue && !meals.loading
          ? ColoredBox(
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IcueButton(
                    label: l10n.next,
                    isFullWidth: true,
                    size: IcueButtonSize.large,
                    onPressed: () => context.push(MessMealsRoutes.optionsPath),
                  ),
                ),
              ),
            )
          : null,
      body: IcueSheetBody(
        loading: meals.loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Text(
                l10n.studentDetails,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      _InfoRow(label: l10n.name, value: student?.name ?? ''),
                      const Divider(height: 32),
                      _InfoRow(
                        label: l10n.admissionNumber,
                        value: student?.admissionNumber ?? '',
                      ),
                      const Divider(height: 32),
                      _InfoRow(
                        label: l10n.classLabel,
                        value: student?.standard ?? '',
                      ),
                      const Divider(height: 32),
                      _InfoRow(
                        label: l10n.mess,
                        badge: IcueStatusPill(
                          label: annual
                              ? l10n.subscribedAnnual
                              : l10n.nonSubscriber,
                          color: annual
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          icon: annual
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.badge});

  final String label;
  final String? value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 12,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        ?badge,
        if (value != null)
          Flexible(
            child: Text(
              value!,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
