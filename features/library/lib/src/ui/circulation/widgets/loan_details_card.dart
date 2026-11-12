import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Card displaying borrower details, loan schedule, and overdue alerts.
class LoanDetailsCard extends StatelessWidget {
  const LoanDetailsCard({
    super.key,
    required this.loan,
    required this.isOverdue,
    required this.overdueDays,
    required this.fineAmount,
  });

  final LibraryLoan loan;
  final bool isOverdue;
  final int overdueDays;
  final double fineAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOverdue) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: colors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fineAmount > 0
                            ? 'Overdue Fine: ${fineAmount.toRupees()}'
                            : 'Overdue (Within grace period)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fineAmount > 0
                            ? 'Book is $overdueDays day${overdueDays == 1 ? '' : 's'} late. Fine will be billed upon return.'
                            : 'Book is $overdueDays day${overdueDays == 1 ? '' : 's'} late. No fine accrued yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildMemberCard(theme, colors),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _detailRow(
                theme,
                colors,
                Icons.event_available_rounded,
                'Issued date',
                loan.issuedDate.toDisplayDay(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, thickness: 0.5),
              ),
              _detailRow(
                theme,
                colors,
                Icons.event_rounded,
                'Due date',
                loan.dueDate.toDisplayDay(),
                valueColor: isOverdue ? colors.error : null,
                fontWeight: isOverdue ? FontWeight.w700 : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, thickness: 0.5),
              ),
              _detailRow(
                theme,
                colors,
                Icons.autorenew_rounded,
                'Renewals',
                '${loan.renewals} of ${loan.maxRenewals} used',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(ThemeData theme, ColorScheme colors) {
    final classText = loan.memberClass != null && loan.memberClass!.isNotEmpty
        ? 'Class ${loan.memberClass}${loan.memberSection != null && loan.memberSection!.isNotEmpty ? '-${loan.memberSection}' : ''}'
        : null;
    final admissionText =
        loan.admissionNumber != null && loan.admissionNumber!.isNotEmpty
        ? 'Adm. #${loan.admissionNumber}'
        : null;
    final roleText = loan.memberType == 'student'
        ? 'Student'
        : (loan.memberType == 'teacher' ? 'Teacher' : 'Staff');

    final subtitleParts = [
      ?classText,
      ?admissionText,
      if (classText == null && admissionText == null) roleText,
      'ERP #${loan.personErpId}',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              loan.memberType == 'student'
                  ? Icons.school_rounded
                  : Icons.badge_rounded,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.memberLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    ColorScheme colors,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    FontWeight? fontWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: fontWeight ?? FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
