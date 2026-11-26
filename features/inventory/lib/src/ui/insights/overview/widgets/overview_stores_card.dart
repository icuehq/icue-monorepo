import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Live per-store stock & health comparison read from `inventoryStats/overall.stores`.
class OverviewStoresCard extends StatelessWidget {
  const OverviewStoresCard({
    required this.stores,
    required this.selectedStoreId,
    required this.onSelectStore,
    super.key,
  });

  final List<StoreOverviewSummary> stores;
  final String? selectedStoreId;
  final ValueChanged<String?> onSelectStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 19,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stores at a glance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap a store to focus dashboard figures',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedStoreId != null)
                  IcueButton(
                    label: 'Show all',
                    onPressed: () => onSelectStore(null),
                    variant: IcueButtonVariant.ghost,
                    size: IcueButtonSize.small,
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          for (var index = 0; index < stores.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.30),
              ),
            _StoreRow(
              summary: stores[index],
              selected: stores[index].store.id == selectedStoreId,
              onTap: () => onSelectStore(
                stores[index].store.id == selectedStoreId
                    ? null
                    : stores[index].store.id,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final StoreOverviewSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issueCount = summary.lowStock + summary.outOfStock;
    final badgeColor = summary.outOfStock > 0
        ? theme.colorScheme.error
        : summary.lowStock > 0
        ? const Color(0xFFD97706)
        : Colors.green.shade700;
    final badgeLabel = summary.outOfStock > 0
        ? '${summary.outOfStock} out'
        : summary.lowStock > 0
        ? '${summary.lowStock} low'
        : 'Healthy';

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : issueCount > 0
                      ? badgeColor
                      : Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.available.toQuantityText()} units available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    summary.value.toRupees(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
