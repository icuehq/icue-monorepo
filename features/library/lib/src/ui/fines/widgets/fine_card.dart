import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

class FineCard extends StatelessWidget {
  const FineCard({super.key, required this.fine, required this.onTap});

  final LibraryFine fine;
  final VoidCallback onTap;

  (Color, Color) _statusColors(ThemeData theme) {
    return switch (fine.status) {
      'paid' => (Colors.green.shade700, Colors.green.withValues(alpha: 0.12)),
      'partially_paid' => (
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'waived' => (
        Colors.blueGrey.shade700,
        Colors.blueGrey.withValues(alpha: 0.12),
      ),
      _ => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
    };
  }

  IconData _typeIcon() {
    return switch (fine.type) {
      'lost' => Icons.help_outline_rounded,
      'damaged' => Icons.report_problem_outlined,
      _ => Icons.schedule_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusColor, statusBackground) = _statusColors(theme);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon(), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fine.fineNumber,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                humanizeStatus(fine.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              fine.memberType == 'teacher'
                                  ? Icons.person_outline_rounded
                                  : Icons.school_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                fine.memberLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metaPill(
                    context,
                    Icons.category_outlined,
                    fineTypeLabel(fine.type),
                  ),
                  if (fine.barcode != null && fine.barcode!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _metaPill(context, Icons.qr_code_2_rounded, fine.barcode!),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fine.outstanding > 0
                            ? 'Due: ${fine.outstanding.toRupees()}'
                            : fine.status == 'waived'
                            ? 'Waived'
                            : 'Paid',
                        style: TextStyle(
                          color: fine.outstanding > 0
                              ? theme.colorScheme.error
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (fine.outstanding > 0 && fine.paid > 0)
                        Text(
                          'Total ${fine.amount.toRupees()}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaPill(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
