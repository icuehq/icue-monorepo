import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class VerificationInitialEmptyState extends StatelessWidget {
  const VerificationInitialEmptyState({this.onCreate, super.key});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.fact_check_outlined,
    title: 'No stock verification sessions',
    message: 'Start a verification session to scan physical books and identify missing, misplaced, or unexpected copies.',
    actionLabel: 'New verification session',
    actionIcon: Icons.add_rounded,
    onAction: onCreate,
  );
}
