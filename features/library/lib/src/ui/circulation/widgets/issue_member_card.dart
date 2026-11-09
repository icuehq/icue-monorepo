import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// Card showing the selected borrower and their current borrowing standing at the desk.
class IssueMemberCard extends StatelessWidget {
  const IssueMemberCard({
    required this.person,
    this.member,
    this.onChange,
    this.disabled = false,
    super.key,
  });

  final LibraryPerson person;
  final LibraryMember? member;
  final VoidCallback? onChange;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBlocked = member?.blocked ?? false;
    final activeLoansCount = member?.activeLoans ?? 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBlocked ? colorScheme.error : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    person.isStudent
                        ? Icons.school_rounded
                        : Icons.badge_outlined,
                    color: isBlocked
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              person.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              person.isStudent ? 'Student' : 'Staff',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'ID: ${person.personErpId}',
                          if (person.detail.isNotEmpty) person.detail,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onChange != null)
                  AppButton(
                    label: 'Change',
                    onPressed: disabled ? null : onChange,
                    variant: AppButtonVariant.ghost,
                    leadingIcon: Icons.swap_horiz_rounded,
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 16,
                  color: activeLoansCount > 0
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  activeLoansCount == 1
                      ? '1 book currently on loan'
                      : '$activeLoansCount books currently on loan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: activeLoansCount > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: activeLoansCount > 0
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isBlocked) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Blocked',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
