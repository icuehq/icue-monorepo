import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/policies/widgets/policy_rule_pills.dart';

class PolicyCard extends StatelessWidget {
  const PolicyCard({
    super.key,
    required this.policy,
    required this.libraryName,
    required this.scope,
    required this.canEdit,
    required this.onTap,
    required this.onToggleActive,
  });

  final LibraryPolicy policy;
  final String libraryName;
  final String scope;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: policy.active
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLow,
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
                      switch (policy.memberType) {
                        'student' => Icons.school_outlined,
                        'teacher' => Icons.person_outline_rounded,
                        _ => Icons.groups_outlined,
                      },
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
                          '$libraryName · $scope',
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
              PolicyRulePills(policy: policy),
            ],
          ),
        ),
      ),
    );
  }
}
