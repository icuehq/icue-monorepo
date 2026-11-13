import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_meta_pill.dart';
import 'package:school_library/src/ui/shared/library_record_card.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';
import 'package:school_library/src/ui/shared/member_details.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, required this.onTap});

  final LibraryIncident incident;
  final VoidCallback onTap;

  (Color, Color) _statusColors(ThemeData theme) {
    return incident.isOpen
        ? (
            theme.colorScheme.error,
            theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          )
        : (Colors.green.shade700, Colors.green.withValues(alpha: 0.12));
  }

  IconData _typeIcon() {
    return incident.type == 'lost'
        ? Icons.help_outline_rounded
        : Icons.report_problem_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusColor, statusBackground) = _statusColors(theme);
    final member = incident.memberLabel;

    return LibraryRecordCard(
      onTap: onTap,
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
                          incident.bookTitle ?? incident.barcode,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            incident.id,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        LibraryStatusChip(incident.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (member != null)
                      Row(
                        children: [
                          Icon(
                            incident.memberType == 'EMPLOYEE'
                                ? Icons.person_outline_rounded
                                : Icons.school_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              member,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Reported in library stock',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          MemberDetailsLine(
            classId: incident.memberClassId,
            section: incident.memberSection,
            admissionNumber: incident.admissionNumber,
            isEmployee: incident.memberType == 'EMPLOYEE',
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              LibraryMetaPill(_typeIcon(), humanizeStatus(incident.type)),
              if (incident.severity != null) ...[
                const SizedBox(width: 6),
                LibraryMetaPill(
                  Icons.warning_amber_rounded,
                  humanizeStatus(incident.severity!),
                ),
              ],
              const SizedBox(width: 6),
              LibraryMetaPill(
                Icons.event_outlined,
                incident.reportedDate.toDisplayDay(),
              ),
              const Spacer(),
              if (incident.charge > 0)
                Text(
                  'Charge: ${incident.charge.toRupees()}',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                )
              else if (incident.resolution != null)
                Text(
                  incidentResolutionLabel(incident.resolution),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
