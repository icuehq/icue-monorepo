import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Library dashboard (FRS 11.1): figures for the user's campuses, optionally one library.
class LibDashboardPage extends StatefulWidget {
  const LibDashboardPage({super.key});

  @override
  State<LibDashboardPage> createState() => _LibDashboardPageState();
}

class _LibDashboardPageState extends State<LibDashboardPage> {
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
    final p = context.read<LibraryProvider>();
    if (p.libraries.isEmpty) await p.loadMasters();
    if (!mounted) return;
    await p.loadDashboard(
      library: p.libraries.where((l) => l.id == _libraryId).firstOrNull,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final tiles = [
      for (final (key, label, perms) in libDashboardStats)
        if (perms.any(p.access.can) && p.dashboard[key] != null)
          (key, label, p.dashboard[key]!),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (p.access.can('lib.reports.view'))
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
                for (final l in p.libraries.where((l) => l.active))
                  DropdownMenuItem(value: l.id, child: Text(l.name)),
              ],
              onChanged: (v) {
                _libraryId = v;
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (p.insightsLoading && tiles.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (tiles.isEmpty)
              Center(child: Text(p.errorMessage ?? 'Nothing to show'))
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (key, label, value) in tiles)
                    SizedBox(
                      width: 160,
                      child: Card(
                        child: InkWell(
                          onTap: _targets[key] == null
                              ? null
                              : () => context.push(_targets[key]!),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key == 'fines'
                                      ? value.toStringAsFixed(2)
                                      : '${value.round()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
