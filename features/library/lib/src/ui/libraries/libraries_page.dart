import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/add_library_dialog.dart';
import 'package:school_library/src/ui/libraries/widgets/libraries_table.dart';
import 'package:school_library/src/ui/libraries/widgets/library_card.dart';
import 'package:school_library/src/ui/libraries/widgets/library_empty_states.dart';
import 'package:school_library/src/ui/libraries/widgets/library_filter_header.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

class LibrariesPage extends StatefulWidget {
  const LibrariesPage({super.key});

  @override
  State<LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends State<LibrariesPage> {
  final _searchController = TextEditingController();
  var _statusFilter = LibraryStatusFilter.all;
  String _searchQuery = '';

  /// Librarian display names by ID; Firestore keeps only the IDs.
  Map<String, String> _librarianNames = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final libraryProvider = context.read<LibraryProvider>();
      if (libraryProvider.libraries.isEmpty) {
        await libraryProvider.loadMasters();
      }
    });
    _loadLibrarianNames();
  }

  Future<void> _loadLibrarianNames() async {
    try {
      final users = await context.read<AuthProvider>().usersByRole(
        RoleIds.librarian,
      );
      if (mounted) {
        setState(
          () => _librarianNames = {
            for (final user in users) '${user.id}': user.displayName,
          },
        );
      }
    } catch (error, stack) {
      logError(error, stack, 'Loading librarian names');
      // The list still works without names; librarians show as "—".
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _statusFilter = LibraryStatusFilter.all;
    });
  }

  Future<void> _toggleActive(
    BuildContext context,
    SchoolLibrary library,
  ) async {
    final libraryProvider = context.read<LibraryProvider>();
    final action = library.active ? 'Deactivate' : 'Activate';
    final confirmed = await IcueDialog.confirm(
      context,
      title: '$action library',
      message: library.active
          ? '${library.name} will no longer be available for new '
                'circulation. Existing records are not affected.'
          : '${library.name} will be available again.',
      confirmLabel: action,
      destructive: library.active,
    );
    if (!confirmed || !context.mounted) return;
    final success = await libraryProvider.setLibraryActive(
      library.id,
      active: !library.active,
    );
    if (!success && context.mounted) {
      IcueToast.error(
        context,
        libraryProvider.errorMessage ?? 'Failed to update library status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final allLibraries = libraryProvider.libraries;
    final isWide = context.isWide;
    // Libraries are set up by admins in the portal; a librarian only sees their own.
    final readOnly = libraryProvider.restricted;

    final filteredLibraries = allLibraries.where((lib) {
      final statusOk = switch (_statusFilter) {
        LibraryStatusFilter.all => true,
        LibraryStatusFilter.active => lib.active,
        LibraryStatusFilter.inactive => !lib.active,
      };
      if (!statusOk) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = lib.name.toLowerCase().contains(query);
        final matchLocation =
            lib.location?.toLowerCase().contains(query) ?? false;
        return matchName || matchLocation;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),

        bottom: const LibraryTabBar(
          tabs: librarySettingsTabs,
          activePath: LibraryRoutes.libraryList,
        ),
      ),
      floatingActionButton: !isWide && allLibraries.isNotEmpty && !readOnly
          ? FloatingActionButton.extended(
              onPressed: () => AddLibraryDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Library'),
            )
          : null,
      body: libraryProvider.isLoading && allLibraries.isEmpty
          ? const IcueSkeletonCardList()
          : isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: LibrariesTable(
                libraries: allLibraries,
                librarianNames: _librarianNames,
                readOnly: readOnly,
                onToggleActive: (library) => _toggleActive(context, library),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => libraryProvider.loadMasters(),
              child: allLibraries.isEmpty
                  ? LibraryInitialEmptyState(
                      onAdd: readOnly
                          ? null
                          : () => AddLibraryDialog.show(context),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LibraryFilterHeader(
                          searchController: _searchController,
                          statusFilter: _statusFilter,
                          totalCount: filteredLibraries.length,
                          onSearchChanged: (value) =>
                              setState(() => _searchQuery = value.trim()),
                          onStatusChanged: (filter) =>
                              setState(() => _statusFilter = filter),
                          onClearSearch: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                        Expanded(
                          child: filteredLibraries.isEmpty
                              ? LibraryNoResultsState(
                                  searchQuery: _searchQuery,
                                  onClear: _clearFilters,
                                )
                              : IcueAdaptiveCardList(
                                  padding: const EdgeInsets.all(12),
                                  spacing: 8,
                                  itemCount: filteredLibraries.length,
                                  itemBuilder: (context, index) {
                                    final library = filteredLibraries[index];
                                    return LibraryCard(
                                      library: library,
                                      readOnly: readOnly,
                                      librarianName:
                                          _librarianNames[library.librarianId],
                                      onEdit: () => AddLibraryDialog.show(
                                        context,
                                        library: library,
                                      ),
                                      onToggleActive: () =>
                                          _toggleActive(context, library),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
