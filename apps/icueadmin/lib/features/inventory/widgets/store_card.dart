import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';

Widget _metaPill(BuildContext context, IconData icon, String text) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.store,
    required this.canEdit,
    required this.onEdit,
    required this.onToggleActive,
  });

  final InventoryStore store;
  final bool canEdit;
  final ValueChanged<InventoryStore> onEdit;
  final ValueChanged<InventoryStore> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keepersCount = store.storekeeperIds.length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
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
                    color: store.active
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          )
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: store.active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
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
                              store.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!store.active) ...[
                            const SizedBox(width: 8),
                            const InactiveBadge(),
                          ],
                        ],
                      ),
                      if (store.description != null &&
                          store.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          store.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(store);
                      } else if (value == 'toggle') {
                        onToggleActive(store);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              store.active
                                  ? Icons.block_outlined
                                  : Icons.check_circle_outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(store.active ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _metaPill(
                  context,
                  Icons.school_outlined,
                  'Campus ${store.campusId}',
                ),
                if (store.location != null && store.location!.trim().isNotEmpty)
                  _metaPill(
                    context,
                    Icons.place_outlined,
                    store.location!.trim(),
                  ),
                if (keepersCount > 0)
                  _metaPill(
                    context,
                    Icons.people_outline,
                    '$keepersCount keeper${keepersCount == 1 ? '' : 's'}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
