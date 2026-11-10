import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.onToggleBlock,
  });

  final LibraryMember member;
  final VoidCallback onToggleBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = member.isStudent;

    final avatarColor = member.blocked
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final avatarBackground = member.blocked
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.4);

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
                    color: avatarBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isStudent
                        ? Icons.school_outlined
                        : Icons.person_outline_rounded,
                    color: avatarColor,
                    size: 22,
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
                              member.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (member.blocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Blocked',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Can borrow',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ERP ID: ${member.personErpId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                if (member.classId != null) ...[
                  _metaPill(
                    context,
                    Icons.class_outlined,
                    'Class ${member.classId}',
                  ),
                  const SizedBox(width: 6),
                ],
                _metaPill(
                  context,
                  Icons.menu_book_rounded,
                  '${member.activeLoans} on loan',
                  highlight: member.activeLoans > 0,
                ),
                const Spacer(),
                IcueButton(
                  label: member.blocked ? 'Unblock' : 'Block',
                  onPressed: onToggleBlock,
                  variant: IcueButtonVariant.destructive,
                  leadingIcon: member.blocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
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
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final backgroundColor = highlight
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
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
