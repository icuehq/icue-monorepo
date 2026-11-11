import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/home/library_home_page.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_attention_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_collection_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_due_next_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_kpi_grid.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_quick_actions.dart';

/// The Library landing page: the tile grid on phones, the [LibraryOverviewPage] on wide screens.
class LibraryLanding extends StatelessWidget {
  const LibraryLanding({super.key});

  @override
  Widget build(BuildContext context) =>
      context.isWide ? const LibraryOverviewPage() : const LibraryHomePage();
}

const _targets = <String, String>{
  'lost': LibraryRoutes.libraryIncidents,
  'damaged': LibraryRoutes.libraryIncidents,
  'overdue': LibraryRoutes.libraryCirculation,
  'fines': LibraryRoutes.libraryFines,
};

/// Everything about the Library at a glance (FRS 11.1): figures, what needs attention, what is due next.
class LibraryOverviewPage extends StatefulWidget {
  const LibraryOverviewPage({super.key});

  @override
  State<LibraryOverviewPage> createState() => _LibraryOverviewPageState();
}

class _LibraryOverviewPageState extends State<LibraryOverviewPage> {
  String? _libraryId;

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    if (libraryProvider.libraries.isEmpty) await libraryProvider.loadMasters();
    if (!mounted) return;
    await libraryProvider.loadDashboard(
      library: libraryProvider.libraries
          .where((schoolLibrary) => schoolLibrary.id == _libraryId)
          .firstOrNull,
    );
    if (mounted) await libraryProvider.loadLoans();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final stats = libraryProvider.dashboard;
    final wide = context.isWide;

    final filter = SizedBox(
      width: wide ? 240 : double.infinity,
      child: DropdownButtonFormField<String?>(
        initialValue: _libraryId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Library',
          prefixIcon: Icon(Icons.local_library_outlined, size: 18),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(child: Text('All libraries')),
          for (final schoolLibrary in libraryProvider.libraries.where(
            (schoolLibrary) => schoolLibrary.active,
          ))
            DropdownMenuItem(
              value: schoolLibrary.id,
              child: Text(schoolLibrary.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          _libraryId = value;
          _load();
        },
      ),
    );

    final attention = OverviewAttentionCard(
      stats: stats,
      allowed: (key) => stats[key] != null,
      targets: _targets,
    );
    final collection = OverviewCollectionCard(stats: stats);
    final dueNext = OverviewDueNextCard(libraryProvider: libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: ListView(
        padding: EdgeInsets.all(wide ? 24 : 16),
        children: [
          if (wide)
            Row(
              children: [
                const Expanded(child: OverviewQuickActions()),
                const SizedBox(width: 16),
                filter,
              ],
            )
          else ...[
            filter,
            const SizedBox(height: 12),
            const OverviewQuickActions(),
          ],
          const SizedBox(height: 20),
          if (libraryProvider.insightsLoading && stats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(56),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            OverviewKpiGrid(stats: stats),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        collection,
                        const SizedBox(height: 16),
                        dueNext,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: attention),
                ],
              )
            else ...[
              attention,
              const SizedBox(height: 16),
              collection,
              const SizedBox(height: 16),
              dueNext,
            ],
          ],
        ],
      ),
    );
  }
}
