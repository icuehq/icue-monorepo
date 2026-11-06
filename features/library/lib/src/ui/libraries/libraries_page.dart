import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/library_card.dart';
import 'package:school_library/src/ui/libraries/widgets/library_empty_states.dart';
import 'package:school_library/src/ui/libraries/widgets/library_filter_header.dart';
import 'package:school_library/src/ui/libraries/widgets/library_form_sheet.dart';

class LibrariesPage extends StatefulWidget {
  const LibrariesPage({super.key});

  @override
  State<LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends State<LibrariesPage> {
  final _searchController = TextEditingController();
  int? _selectedCampus;
  var _statusFilter = LibraryStatusFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final libraryProvider = context.read<LibraryProvider>();
      if (libraryProvider.libraries.isEmpty) {
        await libraryProvider.loadMasters();
      }
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
      _searchQuery = '';
      _selectedCampus = null;
      _statusFilter = LibraryStatusFilter.all;
    });
  }

  Future<void> _toggleActive(
    BuildContext context,
    SchoolLibrary library,
  ) async {
    final libraryProvider = context.read<LibraryProvider>();
    final success = await libraryProvider.setLibraryActive(
      library.id,
      active: !library.active,
    );
    if (!success && context.mounted) {
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to update library status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.settings');
    final theme = Theme.of(context);
    final allLibraries = libraryProvider.libraries;
    final isWide = context.isWide;

    final campuses = {for (final lib in allLibraries) lib.campusId}.toList()
      ..sort();

    final filteredLibraries = allLibraries.where((lib) {
      if (_selectedCampus != null && lib.campusId != _selectedCampus) {
        return false;
      }
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
        final matchDescription =
            lib.description?.toLowerCase().contains(query) ?? false;
        return matchName || matchLocation || matchDescription;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: () => libraryProvider.loadMasters(),
          ),
        ],
      ),
      floatingActionButton: canEdit && allLibraries.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => LibraryFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Library'),
            )
          : null,
      body: CenteredBody(
        child: libraryProvider.isLoading && allLibraries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => libraryProvider.loadMasters(),
                child: allLibraries.isEmpty
                    ? LibraryInitialEmptyState(
                        canEdit: canEdit,
                        onAdd: () => LibraryFormSheet.show(context),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LibraryFilterHeader(
                            searchController: _searchController,
                            selectedCampus: _selectedCampus,
                            statusFilter: _statusFilter,
                            campuses: campuses,
                            isWide: isWide,
                            canEdit: canEdit,
                            totalCount: filteredLibraries.length,
                            onSearchChanged: (value) =>
                                setState(() => _searchQuery = value.trim()),
                            onCampusChanged: (campus) =>
                                setState(() => _selectedCampus = campus),
                            onStatusChanged: (filter) =>
                                setState(() => _statusFilter = filter),
                            onAddLibrary: () => LibraryFormSheet.show(context),
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
                                : AdaptiveList<SchoolLibrary>(
                                    items: filteredLibraries,
                                    columns: [
                                      AdaptiveColumn(
                                        label: 'Library',
                                        flex: 3,
                                        cell: (context, lib) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.local_library_outlined,
                                                size: 18,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          lib.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (!lib.active) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        const InactiveBadge(),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AdaptiveColumn.text(
                                        'Campus',
                                        (lib) => 'Campus ${lib.campusId}',
                                      ),
                                      AdaptiveColumn.text(
                                        'Location',
                                        (lib) => lib.location ?? '—',
                                        flex: 2,
                                      ),
                                      AdaptiveColumn.text(
                                        'Hours',
                                        (lib) => lib.hours ?? '—',
                                        flex: 2,
                                      ),
                                      AdaptiveColumn.text(
                                        'Contact',
                                        (lib) => lib.contactLine.isEmpty
                                            ? '—'
                                            : lib.contactLine,
                                        flex: 2,
                                      ),
                                      if (canEdit)
                                        AdaptiveColumn(
                                          label: '',
                                          alignment: Alignment.centerRight,
                                          cell: (context, lib) => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                ),
                                                tooltip: 'Edit',
                                                onPressed: () =>
                                                    LibraryFormSheet.show(
                                                      context,
                                                      library: lib,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  lib.active
                                                      ? Icons.block_outlined
                                                      : Icons
                                                            .check_circle_outline_rounded,
                                                  size: 18,
                                                ),
                                                tooltip: lib.active
                                                    ? 'Deactivate'
                                                    : 'Activate',
                                                onPressed: () =>
                                                    _toggleActive(context, lib),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                    cardBuilder: (context, lib) => LibraryCard(
                                      library: lib,
                                      canEdit: canEdit,
                                      onEdit: () => LibraryFormSheet.show(
                                        context,
                                        library: lib,
                                      ),
                                      onToggleActive: () =>
                                          _toggleActive(context, lib),
                                    ),
                                    onTap: canEdit
                                        ? (lib) => LibraryFormSheet.show(
                                            context,
                                            library: lib,
                                          )
                                        : null,
                                  ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}
