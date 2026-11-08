import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';

/// What a report shows, its group on the page and its icon.
const _reportInfo = <String, (String group, IconData icon, String blurb)>{
  'issued': ('Circulation', Icons.outbox_rounded, 'Books currently on loan'),
  'overdue': (
    'Circulation',
    Icons.schedule_rounded,
    'Loans past their due date',
  ),
  'history': ('Circulation', Icons.history_rounded, 'Every loan of a member'),
  'popular': ('Circulation', Icons.trending_up_rounded, 'Most borrowed titles'),
  'inactive': (
    'Circulation',
    Icons.hourglass_empty_rounded,
    'Titles nobody borrowed',
  ),
  'fines': (
    'Fines & incidents',
    Icons.payments_outlined,
    'Fines, payments and waivers',
  ),
  'lost': (
    'Fines & incidents',
    Icons.search_off_rounded,
    'Books reported lost',
  ),
  'damaged': (
    'Fines & incidents',
    Icons.broken_image_outlined,
    'Books reported damaged',
  ),
  'catalogue': (
    'Catalogue & stock',
    Icons.menu_book_outlined,
    'All titles in the catalogue',
  ),
  'accession': (
    'Catalogue & stock',
    Icons.list_alt_rounded,
    'Register of every copy',
  ),
  'stock': (
    'Catalogue & stock',
    Icons.inventory_2_outlined,
    'Copies by status and library',
  ),
  'available': (
    'Catalogue & stock',
    Icons.check_circle_outline,
    'Copies ready to lend',
  ),
  'books': (
    'Catalogue & stock',
    Icons.library_add_outlined,
    'Copies added to the library',
  ),
};

/// Report catalogue (FRS 11.18): searchable, grouped cards in a responsive grid.
class LibraryReportsPage extends StatefulWidget {
  const LibraryReportsPage({super.key});

  @override
  State<LibraryReportsPage> createState() => _LibraryReportsPageState();
}

class _LibraryReportsPageState extends State<LibraryReportsPage> {
  var _search = '';

  (String, IconData, String) _info(LibraryReportDef def) =>
      _reportInfo[def.key] ??
      ('Other', Icons.assessment_outlined, '${def.cols.length} columns');

  Widget _card(BuildContext context, LibraryReportDef def) {
    final theme = Theme.of(context);
    final (_, icon, blurb) = _info(def);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => context.push(LibraryRoutes.libraryReport, extra: def),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      blurb,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.toLowerCase();
    final groups = <String, List<LibraryReportDef>>{};
    for (final def in libraryReports) {
      final (group, _, blurb) = _info(def);
      if (query.isEmpty ||
          def.title.toLowerCase().contains(query) ||
          blurb.toLowerCase().contains(query)) {
        groups.putIfAbsent(group, () => []).add(def);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Library Reports')),
      body: CenteredBody(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.isWide ? 24 : 16,
            vertical: 16,
          ),
          children: [
            Text(
              'Choose a report to filter, search and sort.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search reports',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _search = value.trim()),
                ),
              ),
            ),
            if (groups.isEmpty)
              SizedBox(
                height: 320,
                child: EmptyState.noResults(
                  title: 'No reports match "$_search"',
                  onAction: () => setState(() => _search = ''),
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 10),
                child: Text(
                  entry.key,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 620
                      ? 2
                      : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final def in entry.value)
                        SizedBox(width: width, child: _card(context, def)),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
