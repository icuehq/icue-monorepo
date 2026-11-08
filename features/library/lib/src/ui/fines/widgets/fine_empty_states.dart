import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class FineInitialEmptyState extends StatelessWidget {
  const FineInitialEmptyState({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isAll = status == 'all';
    return EmptyState(
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
  Widget build(BuildContext context) => EmptyState.noResults(
    title: 'No fines match "$searchQuery"',
    message: 'Try searching by member name, fine number, or book barcode.',
    onAction: onClear,
  );
}
