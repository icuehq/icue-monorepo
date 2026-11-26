import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class CatalogueInitialEmptyState extends StatelessWidget {
  const CatalogueInitialEmptyState({required this.onAdd, super.key});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => IcueEmptyState(
    icon: Icons.menu_book_rounded,
    title: 'Catalogue is empty',
    message: 'Start building your school library by cataloguing titles, authors, and classification details.',
    actionLabel: 'Add First Book',
    actionIcon: Icons.add_rounded,
    onAction: onAdd,
  );
}

class CatalogueNoResultsState extends StatelessWidget {
  const CatalogueNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => IcueEmptyState.noResults(
    title: 'No books found',
    message: searchQuery.isNotEmpty
        ? 'No titles match "$searchQuery". Try checking the spelling or removing filters.'
        : 'No books match the selected category or status filters.',
    actionLabel: 'Clear Filters',
    onAction: onClear,
  );
}
