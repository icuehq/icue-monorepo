import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class PolicyInitialEmptyState extends StatelessWidget {
  const PolicyInitialEmptyState({this.onAddDefault, super.key});

  final VoidCallback? onAddDefault;

  @override
  Widget build(BuildContext context) => IcueEmptyState(
    icon: Icons.rule_rounded,
    title: 'No borrowing policies configured',
    message: 'Start with a default policy for everyone (3 books, 14 days, 1 renewal, ₹1 per day overdue fine). You can edit it, or add policies per member type and category with the + button.',
    actionLabel: 'Add default policy',
    actionIcon: Icons.auto_fix_high_rounded,
    onAction: onAddDefault,
  );
}
