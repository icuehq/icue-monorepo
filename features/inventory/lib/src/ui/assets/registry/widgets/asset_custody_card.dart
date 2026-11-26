import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Custody card showing current assignee and past custody log.
class AssetCustodyCard extends StatelessWidget {
  const AssetCustodyCard({
    required this.asset,
    required this.assetsProvider,
    super.key,
  });

  final InventoryAsset asset;
  final AssetsProvider assetsProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignments = assetsProvider.assignments;

    return IcueFormSectionCard(
      title: 'Custody & Assignment',
      icon: Icons.assignment_ind_outlined,
      children: [
        if (asset.assignedTo != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: const Icon(Icons.person, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Currently Assigned',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        asset.assignedTo!.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store_mall_directory_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Available in Store (Not assigned)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (assetsProvider.isLoading && assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (assignments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No previous custody assignments recorded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assignments.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final details = [
                '${assignment.assignedDate.toDisplayDay()} → ${assignment.returnedDate?.toDisplayDay() ?? 'Present'}',
                if (assignment.closedAs != null)
                  humanizeStatus(assignment.closedAs!),
                if (assignment.conditionOut != null)
                  'Out: ${humanizeStatus(assignment.conditionOut!)}',
                if (assignment.conditionIn != null)
                  'In: ${humanizeStatus(assignment.conditionIn!)}',
                if (assignment.acknowledged) 'Acknowledged',
              ];

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  assignment.returnedDate == null
                      ? Icons.person_pin_circle_outlined
                      : Icons.history_edu_outlined,
                  color: assignment.returnedDate == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  assignment.assignee.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  details.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Lifecycle event history and audit log.
class AssetHistoryCard extends StatelessWidget {
  const AssetHistoryCard({required this.assetsProvider, super.key});

  final AssetsProvider assetsProvider;

  IconData _eventIcon(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower.contains('register')) return Icons.app_registration_rounded;
    if (lower.contains('assign')) return Icons.person_add_alt_1_outlined;
    if (lower.contains('transfer')) return Icons.swap_horiz_rounded;
    if (lower.contains('return')) return Icons.assignment_return_outlined;
    if (lower.contains('condition')) return Icons.fact_check_outlined;
    if (lower.contains('retire') || lower.contains('dispose')) {
      return Icons.archive_outlined;
    }
    if (lower.contains('maintenance')) return Icons.build_circle_outlined;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = assetsProvider.history;

    return IcueFormSectionCard(
      title: 'Lifecycle & Audit History',
      icon: Icons.history_rounded,
      children: [
        if (assetsProvider.isLoading && history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No history recorded yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = history[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _eventIcon(event.type),
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  humanizeStatus(event.type.replaceAll('.', ' ')),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                        event.performedAt?.toIndianTime().toNumericDateTime(),
                        event.detail,
                      ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
