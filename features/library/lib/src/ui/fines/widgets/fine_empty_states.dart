import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class FineInitialEmptyState extends StatelessWidget {
  const FineInitialEmptyState({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isAll = status == 'all';
    return IcueEmptyState(
      icon: Icons.payments_outlined,
      title: isAll ? 'No fines on record' : 'No $status fines',
      message: isAll
          ? 'Overdue book penalties, damage charges, and lost book replacement fees appear here.'
          : 'There are currently no fines matching this status filter.',
    );
  }
}

class FineNoResultsState extends StatelessWidget {
  const FineNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: searchQuery.isEmpty
        ? 'No fines match these filters'
        : 'No fines match "$searchQuery"',
    message: 'Search by the exact fine number or accession number.',
    onAction: onClear,
  );
}
