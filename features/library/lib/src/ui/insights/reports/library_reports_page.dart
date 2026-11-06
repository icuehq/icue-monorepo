import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:school_library/school_library.dart';

/// Report catalogue (FRS 11.18).
class LibraryReportsPage extends StatelessWidget {
  const LibraryReportsPage({super.key});

  IconData _reportIcon(String key) => switch (key) {
    'circulation' => Icons.sync_alt_rounded,
    'overdue' => Icons.schedule_rounded,
    'fines' => Icons.payments_outlined,
    'reservations' => Icons.bookmark_outline_rounded,
    'transfers' => Icons.swap_horiz_rounded,
    'verification' => Icons.fact_check_outlined,
    'popular' => Icons.trending_up_rounded,
    'inactive' => Icons.hourglass_empty_rounded,
    _ => Icons.assessment_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Library Reports')),
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Select a report to generate, analyze, or export as CSV / PDF.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final reportDef in libraryReports)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                color: theme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(
                    LibraryRoutes.libraryReport,
                    extra: reportDef,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _reportIcon(reportDef.key),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reportDef.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${reportDef.cols.length} data columns',
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
              ),
          ],
        ),
      ),
    );
  }
}
