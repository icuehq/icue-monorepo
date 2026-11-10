import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/home/library_home_page.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_attention_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_due_next_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_kpi_card.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_quick_actions.dart';

/// The Library landing page: the tile grid on phones, the [LibraryOverviewPage] on wide screens.
class LibraryLanding extends StatelessWidget {
  const LibraryLanding({super.key});

  @override
  Widget build(BuildContext context) =>
      context.isWide ? const LibraryOverviewPage() : const LibraryHomePage();
}

const _sections = <(String, IconData, List<String>)>[
  (
    'Collection',
    Icons.collections_bookmark_outlined,
    ['titles', 'copies', 'available', 'lost', 'damaged'],
  ),
  (
    'Circulation',
    Icons.sync_alt_rounded,
    ['issued', 'pending', 'overdue', 'reserved'],
  ),
  (
    'Members and fines',
    Icons.badge_outlined,
    ['students', 'teachers', 'fines'],
  ),
];

const _icons = <String, IconData>{
  'titles': Icons.menu_book_outlined,
  'copies': Icons.qr_code_2_rounded,
  'available': Icons.check_circle_outline_rounded,
  'lost': Icons.help_outline_rounded,
  'damaged': Icons.report_problem_outlined,
  'issued': Icons.swap_horiz_rounded,
  'pending': Icons.assignment_return_outlined,
  'overdue': Icons.schedule_rounded,
  'reserved': Icons.bookmark_added_outlined,
  'students': Icons.school_outlined,
  'teachers': Icons.person_outline_rounded,
  'fines': Icons.payments_outlined,
};

const _targets = <String, String>{
  'titles': LibraryRoutes.libraryCatalogue,
  'copies': LibraryRoutes.libraryCatalogue,
  'available': LibraryRoutes.libraryCatalogue,
  'lost': LibraryRoutes.libraryIncidents,
  'damaged': LibraryRoutes.libraryIncidents,
  'issued': LibraryRoutes.libraryCirculation,
  'pending': LibraryRoutes.libraryCirculation,
  'overdue': LibraryRoutes.libraryCirculation,
  'reserved': LibraryRoutes.libraryReservations,
  'students': LibraryRoutes.libraryMembers,
  'teachers': LibraryRoutes.libraryMembers,
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
    final theme = Theme.of(context);
    final stats = libraryProvider.dashboard;

    bool allowed(String key) => stats[key] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: context.isWide ? 24 : 16,
          vertical: context.isWide ? 20 : 16,
        ),
        children: [
          // Header Hero Banner
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final dropdown = SizedBox(
                width: isCompact ? double.infinity : 240,
                child: DropdownButtonFormField<String?>(
                  initialValue: _libraryId,
                  decoration: InputDecoration(
                    labelText: 'Filter library',
                    prefixIcon: const Icon(
                      Icons.local_library_outlined,
                      size: 18,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('All libraries')),
                    for (final schoolLibrary in libraryProvider.libraries.where(
                      (schoolLibrary) => schoolLibrary.active,
                    ))
                      DropdownMenuItem(
                        value: schoolLibrary.id,
                        child: Text(
                          schoolLibrary.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    _libraryId = value;
                    _load();
                  },
                ),
              );

              return Container(
                padding: EdgeInsets.all(context.isWide ? 20 : 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library overview',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real-time circulation metrics, collection analytics, and pending actions.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          dropdown,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Library overview',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Real-time circulation metrics, collection analytics, and pending actions.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          dropdown,
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Quick Actions Bar
          const OverviewQuickActions(),

          if (libraryProvider.insightsLoading && stats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(56),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            // KPI Metric Sections
            for (final (title, icon, keys) in _sections)
              if (keys.any(allowed)) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 16.0;
                    final columnCount = (constraints.maxWidth / 220)
                        .floor()
                        .clamp(1, 5);
                    final cardWidth =
                        (constraints.maxWidth - (columnCount - 1) * spacing) /
                        columnCount;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final key in keys)
                          if (allowed(key))
                            OverviewKpiCard(
                              statKey: key,
                              value: stats[key]!,
                              icon: _icons[key] ?? Icons.analytics_outlined,
                              targetRoute: _targets[key],
                              width: cardWidth,
                            ),
                      ],
                    );
                  },
                ),
              ],

            const SizedBox(height: 28),

            // Operational Cards: Attention & Due Next
            LayoutBuilder(
              builder: (context, constraints) {
                final attention = OverviewAttentionCard(
                  stats: stats,
                  allowed: allowed,
                  targets: _targets,
                );
                final dueNext = OverviewDueNextCard(
                  libraryProvider: libraryProvider,
                );

                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [attention, const SizedBox(height: 16), dueNext],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: attention),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: dueNext),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
