import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/library_categories_table.dart';
import 'package:school_library/src/ui/libraries/widgets/library_category_card.dart';
import 'package:school_library/src/ui/libraries/widgets/library_category_controls.dart';
import 'package:school_library/src/ui/libraries/widgets/library_category_dialog.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

class LibraryCategoriesPage extends StatefulWidget {
  const LibraryCategoriesPage({super.key});

  @override
  State<LibraryCategoriesPage> createState() => _LibraryCategoriesPageState();
}

class _LibraryCategoriesPageState extends State<LibraryCategoriesPage> {
  final _searchController = TextEditingController();
  var _statusFilter = LibraryCategoryStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final libraryProvider = context.read<LibraryProvider>();
      if (libraryProvider.categories.isEmpty) libraryProvider.loadMasters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = LibraryCategoryStatusFilter.all;
    });
  }

  Future<void> _toggleActive(
    LibraryProvider provider,
    LibraryCategory category,
  ) async {
    final success = await provider.setCategoryActive(
      category.id,
      active: !category.active,
    );
    if (!success && mounted) {
      showMessage(context, provider.errorMessage ?? 'Could not update status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    // Hierarchy: Top-level categories and orphan categories
    final topCategories = libraryProvider.topCategories;
    final topCategoryIds = topCategories.map((category) => category.id).toSet();
    final allTopCategories = [
      ...topCategories,
      ...libraryProvider.categories.where(
        (category) =>
            category.parentId != null &&
            !topCategoryIds.contains(category.parentId),
      ),
    ];

    // Filter categories & nested subcategories
    final matchingGroups = <(LibraryCategory, List<LibraryCategory>)>[];
    var totalSubsCount = 0;

    for (final top in allTopCategories) {
      final topSubs = libraryProvider.categories
          .where((candidate) => candidate.parentId == top.id)
          .toList();

      final topMatchesStatus = switch (_statusFilter) {
        LibraryCategoryStatusFilter.all => true,
        LibraryCategoryStatusFilter.active => top.active,
        LibraryCategoryStatusFilter.inactive => !top.active,
      };

      final topMatchesQuery =
          !isSearching ||
          top.name.toLowerCase().contains(query) ||
          (top.description?.toLowerCase().contains(query) ?? false);

      final matchingSubs = topSubs.where((sub) {
        final subStatusOk = switch (_statusFilter) {
          LibraryCategoryStatusFilter.all => true,
          LibraryCategoryStatusFilter.active => sub.active,
          LibraryCategoryStatusFilter.inactive => !sub.active,
        };
        if (!subStatusOk) return false;

        if (!isSearching) return true;
        return sub.name.toLowerCase().contains(query) ||
            (sub.description?.toLowerCase().contains(query) ?? false);
      }).toList();

      final includeTop =
          (topMatchesStatus && topMatchesQuery) || matchingSubs.isNotEmpty;

      if (includeTop) {
        final effectiveSubs = isSearching && !topMatchesQuery
            ? matchingSubs
            : topSubs.where((sub) {
                return switch (_statusFilter) {
                  LibraryCategoryStatusFilter.all => true,
                  LibraryCategoryStatusFilter.active => sub.active,
                  LibraryCategoryStatusFilter.inactive => !sub.active,
                };
              }).toList();

        matchingGroups.add((top, effectiveSubs));
        totalSubsCount += effectiveSubs.length;
      }
    }

    final hasAnyCategories = libraryProvider.categories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book categories'),

        bottom: const LibraryTabBar(
          tabs: librarySettingsTabs,
          activePath: LibraryRoutes.libraryCategories,
        ),
      ),
      floatingActionButton: hasAnyCategories && !context.isWide
          ? FloatingActionButton.extended(
              onPressed: () => LibraryCategoryDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Category'),
            )
          : null,
      body: Builder(
        builder: (context) {
          final isWide = context.isWide;
          final contentPadding = EdgeInsets.symmetric(
            horizontal: isWide ? 24.0 : 16.0,
            vertical: 16.0,
          );

          if (libraryProvider.isLoading && !hasAnyCategories) {
            return const Center(child: CircularProgressIndicator());
          }

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: LibraryCategoriesTable(
                categories: libraryProvider.categories,
                onToggleActive: (category) =>
                    _toggleActive(libraryProvider, category),
              ),
            );
          }

          if (!hasAnyCategories) {
            return LibraryCategoryEmptyState(
              onAdd: () => LibraryCategoryDialog.show(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => libraryProvider.loadMasters(),
            child: ListView(
              padding: contentPadding,
              children: [
                LibraryCategorySearchBar(
                  searchController: _searchController,
                  isWide: isWide,
                  statusFilter: _statusFilter,
                  onSearchChanged: (_) => setState(() {}),
                  onFilterChanged: (filter) =>
                      setState(() => _statusFilter = filter),
                  onAddCategory: () => LibraryCategoryDialog.show(context),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${matchingGroups.length} ${matchingGroups.length == 1 ? 'category' : 'categories'} · $totalSubsCount ${totalSubsCount == 1 ? 'subcategory' : 'subcategories'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (matchingGroups.isEmpty)
                  LibraryCategoryNoResultsState(
                    query: query,
                    onClear: _clearFilters,
                  )
                else
                  Column(
                    children: [
                      for (final (top, subs) in matchingGroups)
                        LibraryCategoryCard(
                          key: ValueKey(top.id),
                          category: top,
                          subcategories: subs,
                          initiallyExpanded: isSearching,
                          onViewBooks: (category) => context.push(
                            '${LibraryRoutes.libraryCatalogue}?category=${category.id}',
                          ),
                          onEdit: (category) => LibraryCategoryDialog.show(
                            context,
                            category: category,
                          ),
                          onAddSubcategory: (category) =>
                              LibraryCategoryDialog.show(
                                context,
                                parentId: category.id,
                              ),
                          onToggleActive: (category) =>
                              _toggleActive(libraryProvider, category),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
