import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class LibraryInitialEmptyState extends StatelessWidget {
  const LibraryInitialEmptyState({required this.onAdd, super.key});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => IcueEmptyState(
    icon: Icons.local_library_outlined,
    title: 'No libraries configured',
    message: 'Set up the libraries of this branch to manage book circulation, copy inventories, and borrow policies.',
    actionLabel: 'Add Library',
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
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: searchQuery.isNotEmpty
        ? 'No libraries matching "$searchQuery"'
        : 'No libraries match the active filter',
    actionLabel: 'Clear filters',
    onAction: onClear,
  );
}
