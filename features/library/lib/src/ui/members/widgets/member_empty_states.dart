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
    title: searchQuery.isEmpty
        ? 'No members match these filters'
        : 'No member with ERP ID "$searchQuery"',
    message: 'Search by the exact ERP ID, or clear the filters.',
    onAction: onClear,
  );
}
