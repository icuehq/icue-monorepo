import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class MemberInitialEmptyState extends StatelessWidget {
  const MemberInitialEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const IcueEmptyState(
    icon: Icons.groups_outlined,
    title: 'No borrowers yet',
    message: 'Members are enrolled automatically when they first borrow a book from the circulation desk.',
  );
}

class MemberNoResultsState extends StatelessWidget {
  const MemberNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: 'No members match "$searchQuery"',
    message: 'Try searching by another name, ERP ID, or class number.',
    onAction: onClear,
  );
}
