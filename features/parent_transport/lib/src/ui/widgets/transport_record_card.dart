import 'package:flutter/material.dart';
import 'package:parent_transport/src/models/transport_record.dart';

class TransportRecordCard extends StatelessWidget {
  const TransportRecordCard({required this.record, super.key});

  final TransportRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 12,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer.withValues(
                    alpha: 0.15,
                  ),
                  child: Icon(
                    record.isPickup
                        ? Icons.directions_bus_filled_rounded
                        : Icons.directions_bus_filled_outlined,
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.routeNo,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        record.message,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.mode,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              spacing: 8,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                Text(
                  record.date,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
                Text(
                  record.time,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
