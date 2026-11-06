import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class CirculationInitialEmptyState extends StatelessWidget {
  const CirculationInitialEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.swap_horiz_rounded,
    title: 'No active loans',
    message: 'Tap Issue to lend a book to a student or staff member.',
  );
}

class CirculationNoResultsState extends StatelessWidget {
  const CirculationNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyState.noResults(
    title: 'No loans match "$searchQuery"',
    message: 'Try searching by another member name, accession number, or loan number.',
    onAction: onClear,
  );
}
