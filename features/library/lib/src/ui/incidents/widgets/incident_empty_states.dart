import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class IncidentInitialEmptyState extends StatelessWidget {
  const IncidentInitialEmptyState({
    required this.status,
    this.onReport,
    super.key,
  });

  final String status;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'open';
    return IcueEmptyState(
      icon: Icons.report_problem_outlined,
      title: isOpen ? 'No open incidents' : 'No $status incidents',
      message: isOpen
          ? 'Lost and damaged books reported by students or teachers appear here.'
          : 'There are currently no incidents matching this filter.',
      actionLabel: 'Report incident',
      actionIcon: Icons.report_problem_outlined,
      onAction: onReport,
    );
  }
}

class IncidentNoResultsState extends StatelessWidget {
  const IncidentNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: 'No incidents match "$searchQuery"',
    message: 'Try searching by another copy barcode, member name, or incident number.',
    onAction: onClear,
  );
}
