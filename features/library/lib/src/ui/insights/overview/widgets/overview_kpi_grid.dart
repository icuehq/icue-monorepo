import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/insights/overview/widgets/overview_kpi_card.dart';

/// Headline figures of the Library overview, two per row on phones up to five on desktop.
class OverviewKpiGrid extends StatelessWidget {
  const OverviewKpiGrid({required this.stats, super.key});

  final Map<String, num?> stats;

  /// `82% of copies`, or null when either figure is unknown or zero.
  String? _share(String part, String whole, String suffix) {
    final partValue = stats[part];
    final wholeValue = stats[whole];
    if (partValue == null || wholeValue == null || wholeValue <= 0) return null;
    return '${(partValue / wholeValue * 100).round()}% $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final overdue = stats['overdue'] ?? 0;
    final fines = stats['fines'] ?? 0;

    // Figures a role may not see come back null and are left out.
    final tiles = <(String, String, num?, IconData, String?, String?, Color?)>[
      (
        'copies',
        'Total Books',
        stats['copies'],
        Icons.menu_book_outlined,
        null,
        LibraryRoutes.libraryCatalogue,
        null,
      ),
      (
        'available',
        'Available now',
        stats['available'],
        Icons.check_circle_outline_rounded,
        _share('available', 'copies', 'of copies'),
        LibraryRoutes.libraryCatalogue,
        Colors.green.shade700,
      ),
      (
        'issued',
        'Issued Books',
        stats['issued'],
        Icons.swap_horiz_rounded,
        _share('issued', 'copies', 'of copies'),
        LibraryRoutes.libraryCirculation,
        null,
      ),
      (
        'overdue',
        'Overdue',
        stats['overdue'],
        Icons.schedule_rounded,
        _share('overdue', 'pending', 'of active loans'),
        LibraryRoutes.libraryCirculation,
        overdue > 0 ? danger : null,
      ),
      (
        'fines',
        'Outstanding fines',
        stats['fines'],
        Icons.payments_outlined,
        fines > 0 ? 'To be collected' : 'Nothing due',
        LibraryRoutes.libraryFines,
        fines > 0 ? danger : null,
      ),
      (
        'students',
        'Student members',
        stats['students'],
        Icons.school_outlined,
        null,
        LibraryRoutes.libraryMembers,
        null,
      ),
      (
        'teachers',
        'Staff members',
        stats['teachers'],
        Icons.person_outline_rounded,
        null,
        LibraryRoutes.libraryMembers,
        null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (key, label, value, icon, caption, route, color)
                in tiles)
              if (value != null)
                OverviewKpiCard(
                  label: label,
                  value: key == 'fines' ? value.toRupees() : '${value.round()}',
                  icon: icon,
                  caption: caption,
                  route: route,
                  color: color,
                  width: width,
                ),
          ],
        );
      },
    );
  }
}
