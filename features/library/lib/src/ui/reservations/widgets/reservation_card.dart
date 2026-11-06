import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.queuePosition,
    this.onCancel,
  });

  final LibraryReservation reservation;
  final int? queuePosition;
  final VoidCallback? onCancel;

  (Color, Color) _statusColors(ThemeData theme) {
    return switch (reservation.status) {
      'ready' => (Colors.green.shade700, Colors.green.withValues(alpha: 0.12)),
      'waiting' => (
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'fulfilled' => (
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      'expired' => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
      _ => (Colors.grey.shade700, Colors.grey.withValues(alpha: 0.12)),
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
                  child: Icon(
                    reservation.status == 'ready'
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_outline_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reservation.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              reservation.status == 'waiting' &&
                                      queuePosition != null
                                  ? 'Queue #$queuePosition'
                                  : reservationStatusLabel(reservation.status),
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
                            reservation.memberType == 'teacher'
                                ? Icons.person_outline_rounded
                                : Icons.school_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              reservation.memberLabel,
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
                _metaPill(context, Icons.tag_rounded, reservation.number),
                if (reservation.status == 'ready' &&
                    reservation.holdUntil != null) ...[
                  const SizedBox(width: 6),
                  _metaPill(
                    context,
                    Icons.event_outlined,
                    'Hold until ${reservation.holdUntil!.toDisplayDay()}',
                    highlight: true,
                  ),
                ] else if (reservation.status == 'fulfilled' &&
                    reservation.fulfilledCopyId != null) ...[
                  const SizedBox(width: 6),
                  _metaPill(
                    context,
                    Icons.check_circle_outline,
                    'Copy ${reservation.fulfilledCopyId}',
                  ),
                ],
                const Spacer(),
                if (onCancel != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    onPressed: onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(
    BuildContext context,
    IconData icon,
    String text, {
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final backgroundColor = highlight
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
