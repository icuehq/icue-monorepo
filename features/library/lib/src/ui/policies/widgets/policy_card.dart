import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

class PolicyCard extends StatelessWidget {
  const PolicyCard({
    super.key,
    required this.policy,
    required this.libraryName,
    required this.canEdit,
    required this.onTap,
    required this.onToggleActive,
  });

  final LibraryPolicy policy;
  final String libraryName;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = policy.memberType == 'student';

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
        onTap: canEdit ? onTap : null,
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
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isStudent
                          ? Icons.school_outlined
                          : Icons.person_outline_rounded,
                      color: theme.colorScheme.primary,
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
                                policy.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!policy.active) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$libraryName · ${policy.appliesTo}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: policy.active ? 'Deactivate' : 'Activate',
                      icon: Icon(
                        policy.active
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        color: policy.active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      onPressed: onToggleActive,
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
                  _metaPill(
                    context,
                    Icons.menu_book_rounded,
                    'Max ${policy.maxBooks} ${policy.maxBooks == 1 ? 'book' : 'books'}',
                  ),
                  _metaPill(
                    context,
                    Icons.schedule_rounded,
                    '${policy.loanDays} days duration',
                  ),
                  _metaPill(
                    context,
                    Icons.autorenew_rounded,
                    '${policy.maxRenewals} renewals',
                  ),
                  if (policy.fineAmount > 0)
                    _metaPill(
                      context,
                      Icons.payments_outlined,
                      'Fine: ${policy.fineAmount.toRupees()}/day',
                      highlight: true,
                    ),
                ],
              ),
            ],
          ),
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
