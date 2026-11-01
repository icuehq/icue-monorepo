import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/stat_tile_grid.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Library dashboard (FRS 11.1): figures for the user's campuses, optionally one library.
class LibraryDashboardPage extends StatefulWidget {
  const LibraryDashboardPage({super.key});

  @override
  State<LibraryDashboardPage> createState() => _LibDashboardPageState();
}

class _LibDashboardPageState extends State<LibraryDashboardPage> {
  String? _libraryId;

  // Where a tile leads (FRS 11.1 actions); null = not tappable.
  static const _targets = {
    'titles': AppRoutes.libraryCatalogue,
    'copies': AppRoutes.libraryCopies,
    'available': AppRoutes.libraryCopies,
    'issued': AppRoutes.libraryCirculation,
    'pending': AppRoutes.libraryCirculation,
    'overdue': AppRoutes.libraryCirculation,
    'reserved': AppRoutes.libraryReservations,
    'students': AppRoutes.libraryMembers,
    'teachers': AppRoutes.libraryMembers,
    'fines': AppRoutes.libraryFines,
  };

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    if (libraryProvider.libraries.isEmpty) await libraryProvider.loadMasters();
    if (!mounted) return;
    await libraryProvider.loadDashboard(
      library: libraryProvider.libraries
          .where((schoolLibrary) => schoolLibrary.id == _libraryId)
          .firstOrNull,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final tiles = [
      for (final (key, label, permissions) in libraryDashboardStats)
        if (permissions.any(libraryProvider.access.can) &&
            libraryProvider.dashboard[key] != null)
          StatTile(
            label: label,
            value: libraryProvider.dashboard[key]!,
            route: _targets[key],
            isAmount: key == 'fines',
          ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (libraryProvider.access.can('library.reports.view'))
            IconButton(
              tooltip: 'Reports',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () => context.push(AppRoutes.libraryReports),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _libraryId,
              decoration: const InputDecoration(labelText: 'Library'),
              items: [
                const DropdownMenuItem(child: Text('All libraries')),
                for (final schoolLibrary in libraryProvider.libraries.where(
                  (schoolLibrary) => schoolLibrary.active,
                ))
                  DropdownMenuItem(
                    value: schoolLibrary.id,
                    child: Text(schoolLibrary.name),
                  ),
              ],
              onChanged: (value) {
                _libraryId = value;
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (libraryProvider.insightsLoading && tiles.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (tiles.isEmpty)
              Center(
                child: Text(libraryProvider.errorMessage ?? 'Nothing to show'),
              )
            else
              StatTileGrid(tiles: tiles),
          ],
        ),
      ),
    );
  }
}
