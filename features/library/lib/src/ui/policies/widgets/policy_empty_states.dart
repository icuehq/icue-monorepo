import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class PolicyInitialEmptyState extends StatelessWidget {
  const PolicyInitialEmptyState({this.onCreate, super.key});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.rule_rounded,
    title: 'No borrowing policies configured',
    message: 'Define policies per library to set maximum books allowed, loan duration, renewals, and overdue fine amounts.',
    actionLabel: 'Add borrowing policy',
    actionIcon: Icons.add_rounded,
    onAction: onCreate,
  );
}
