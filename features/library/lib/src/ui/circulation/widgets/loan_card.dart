import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_meta_pill.dart';
import 'package:school_library/src/ui/shared/library_record_card.dart';

class LoanCard extends StatelessWidget {
  const LoanCard({
    super.key,
    required this.loan,
    required this.today,
    required this.onTap,
  });

  final LibraryLoan loan;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysLate = loan.overdueOn(today);
    final isLate = daysLate > 0;

    final statusColor = isLate
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final statusBackground = isLate
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.4);

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
                child: Icon(
                  isLate ? Icons.schedule_rounded : Icons.menu_book_rounded,
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
                        Text(
                          loan.bookLabel,
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
                            loan.id,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
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
                            isLate ? '$daysLate d late' : 'On time',
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
                          loan.memberType == 'EMPLOYEE'
                              ? Icons.person_outline_rounded
                              : Icons.school_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            loan.memberLabel,
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (loan.memberClassId != null)
                LibraryMetaPill(
                  Icons.class_outlined,
                  context.watch<LibraryProvider>().classLabel(
                    loan.memberClassId,
                    loan.memberSection,
                  ),
                ),
              if (loan.memberType == 'EMPLOYEE')
                const LibraryMetaPill(Icons.badge_outlined, 'Employee'),
              if (loan.admissionNumber?.isNotEmpty ?? false)
                LibraryMetaPill(
                  Icons.badge_outlined,
                  '${loan.memberType == 'STUDENT' ? 'Adm.' : 'Staff no.'} ${loan.admissionNumber}',
                ),
              LibraryMetaPill(
                Icons.calendar_today_outlined,
                'Issued ${loan.issuedDate.toDisplayDay()}',
              ),
              LibraryMetaPill(
                Icons.event_outlined,
                'Due ${loan.dueDate.toDisplayDay()}',
                tone: LibraryPillTone.error,
              ),
              if (loan.renewals > 0)
                LibraryMetaPill(
                  Icons.autorenew_rounded,
                  'Renewed ${loan.renewals}x',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
