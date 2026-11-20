import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// The loan rules of a policy as compact icon pills.
class PolicyRulePills extends StatelessWidget {
  const PolicyRulePills({super.key, required this.policy});

  final LibraryPolicy policy;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      _pill(
        context,
        Icons.menu_book_rounded,
        'Max ${policy.maxBooks} ${policy.maxBooks == 1 ? 'book' : 'books'}',
      ),
      _pill(context, Icons.schedule_rounded, '${policy.loanDays} days'),
      _pill(
        context,
        Icons.autorenew_rounded,
        '${policy.maxRenewals} ${policy.maxRenewals == 1 ? 'renewal' : 'renewals'}',
      ),
      if (policy.fineAmount > 0)
        _pill(
          context,
          Icons.payments_outlined,
          'Fine ${policy.fineAmount.toRupees()}/day',
          highlight: true,
        ),
    ],
  );

  static Widget _pill(
    BuildContext context,
    IconData icon,
    String text, {
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final backgroundColor = highlight
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return IcueStatusPill(
      label: text,
      color: color,
      background: backgroundColor,
      icon: icon,
      bordered: false,
    );
  }
}
