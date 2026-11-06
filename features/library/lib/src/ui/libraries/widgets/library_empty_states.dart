import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class LibraryInitialEmptyState extends StatelessWidget {
  const LibraryInitialEmptyState({
    required this.canEdit,
    required this.onAdd,
    super.key,
  });

  final bool canEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.local_library_outlined,
    title: 'No libraries configured',
    message: 'Set up physical or campus library branches to manage book circulation, copy inventories, and borrow policies.',
    actionLabel: canEdit ? 'Add Library' : null,
    actionIcon: Icons.add_rounded,
    onAction: onAdd,
  );
}

class LibraryNoResultsState extends StatelessWidget {
  const LibraryNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyState.noResults(
    title: searchQuery.isNotEmpty
        ? 'No libraries matching "$searchQuery"'
        : 'No libraries match the active filter',
    actionLabel: 'Clear filters',
    onAction: onClear,
  );
}
