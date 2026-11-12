import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class CirculationInitialEmptyState extends StatelessWidget {
  const CirculationInitialEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const IcueEmptyState(
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
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: searchQuery.isEmpty
        ? 'No loans match these filters'
        : 'No loan matches "$searchQuery"',
    message: 'Search by the exact loan, accession or admission number.',
    onAction: onClear,
  );
}
