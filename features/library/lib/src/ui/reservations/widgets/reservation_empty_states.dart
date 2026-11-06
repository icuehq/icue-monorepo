import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class ReservationInitialEmptyState extends StatelessWidget {
  const ReservationInitialEmptyState({
    required this.status,
    required this.onReserve,
    super.key,
  });

  final String status;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final isWaiting = status == 'waiting';
    return EmptyState(
      icon: Icons.bookmark_outline_rounded,
      title: isWaiting ? 'No waiting reservations' : 'No $status reservations',
      message: isWaiting
          ? 'Reserve books on loan for students or teachers to put them in line.'
          : 'There are currently no reservations with this status.',
      actionLabel: 'Place reservation',
      actionIcon: Icons.bookmark_add_outlined,
      onAction: onReserve,
    );
  }
}

class ReservationNoResultsState extends StatelessWidget {
  const ReservationNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyState.noResults(
    title: 'No reservations match "$searchQuery"',
    message:
        'Try searching by another title, member name, or reservation number.',
    onAction: onClear,
  );
}
