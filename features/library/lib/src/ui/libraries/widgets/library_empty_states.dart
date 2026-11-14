import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class LibraryInitialEmptyState extends StatelessWidget {
  const LibraryInitialEmptyState({this.onAdd, super.key});

  /// Null when the user may not add libraries (a librarian): the message then asks for an assignment.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => IcueEmptyState(
    icon: Icons.local_library_outlined,
    title: onAdd == null ? 'No library assigned' : 'No libraries configured',
    message: onAdd == null
        ? 'Ask your administrator to assign a library to you.'
        : 'Set up the libraries of this branch to manage book circulation, copy inventories, and borrow policies.',
    actionLabel: onAdd == null ? null : 'Add Library',
    actionIcon: onAdd == null ? null : Icons.add_rounded,
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
