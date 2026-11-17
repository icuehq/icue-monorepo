import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:school_connect/src/models/event_timing.dart';
import 'package:school_connect/src/models/school_event.dart';

class EventListItem extends StatelessWidget {
  const EventListItem({required this.event, required this.onTap, super.key});

  final SchoolEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final start = parseEventDate(event.startDate);
    final end = parseEventDate(event.endDate);
    final (:phase, :daysToGo) = eventPhase(start, end, DateTime.now());
    final (statusText, statusColor) = switch (phase) {
      EventPhase.upcoming => (
        l10n.eventDaysToGo(daysToGo),
        Colors.blue.shade700,
      ),
      EventPhase.ended => (l10n.eventEnded, Colors.red.shade700),
      EventPhase.happeningNow => (
        l10n.eventHappeningNow,
        Colors.green.shade700,
      ),
      EventPhase.unknown => (l10n.eventDateMissing, Colors.grey),
    };
    final days = eventDurationDays(start, end);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Column(
                spacing: 4,
                children: [
                  Text(
                    start == null ? '--' : DateFormat('dd').format(start),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  Text(
                    start == null ? '' : DateFormat('MMM').format(start),
                    style: TextStyle(
                      fontSize: 14,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    spacing: 4,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      Text(
                        event.startDate == event.endDate
                            ? event.startDate
                            : '${event.startDate} - ${event.endDate}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (days != null)
                    Row(
                      spacing: 4,
                      children: [
                        Icon(Icons.calendar_month, size: 16, color: primary),
                        Text(
                          l10n.eventDuration,
                          style: TextStyle(fontSize: 14, color: primary),
                        ),
                        Text(
                          l10n.eventDays(days),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(
                Icons.arrow_forward_ios,
                color: primary.withValues(alpha: 0.6),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
