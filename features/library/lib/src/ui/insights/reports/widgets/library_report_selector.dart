import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// Visual report cards to switch between the 4 library report types.
class LibraryReportSelector extends StatelessWidget {
  const LibraryReportSelector({
    required this.reports,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<LibraryReportDef> reports;
  final LibraryReportDef selected;
  final ValueChanged<LibraryReportDef> onSelected;

  IconData _iconFor(LibraryReportDef def) => switch (def.kind) {
    LibraryReportKind.loans => Icons.sync_alt_rounded,
    LibraryReportKind.monthly => Icons.calendar_month_rounded,
    LibraryReportKind.student => Icons.school_outlined,
    LibraryReportKind.staff => Icons.badge_outlined,
  };

  Widget _card(BuildContext context, LibraryReportDef def) {
    final theme = Theme.of(context);
    final isSelected = def.key == selected.key;
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(def),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(def),
                  color: isSelected ? theme.colorScheme.onPrimary : primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      def.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.blurb,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return Row(
        children: [
          for (var index = 0; index < reports.length; index++) ...[
            if (index > 0) const SizedBox(width: 12),
            Expanded(child: _card(context, reports[index])),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < reports.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            SizedBox(width: 250, child: _card(context, reports[index])),
          ],
        ],
      ),
    );
  }
}
