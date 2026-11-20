import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/request_item/models/request_item_line.dart';
import 'package:icueadmin/features/request_item/widgets/request_selected_item_card.dart';

/// Summary panel showing selected items grouped by store, request purpose, and submission action.
class RequestSummaryPanel extends StatelessWidget {
  const RequestSummaryPanel({
    required this.lines,
    required this.purposeController,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onRemoveLine,
    required this.onClearAll,
    required this.storeName,
    this.onQuantityChanged,
    super.key,
  });

  final List<RequestItemLine> lines;
  final TextEditingController purposeController;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final void Function(RequestItemLine line) onRemoveLine;
  final VoidCallback onClearAll;
  final VoidCallback? onQuantityChanged;
  final String Function(String storeId) storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byStore = <String, List<RequestItemLine>>{};
    for (final line in lines) {
      byStore.putIfAbsent(line.item.storeId, () => []).add(line);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Request Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: lines.isEmpty
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${lines.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: lines.isEmpty
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (lines.isNotEmpty)
                  TextButton.icon(
                    onPressed: isSubmitting ? null : onClearAll,
                    icon: Icon(
                      Icons.clear_all_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No items selected',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse the catalog and tap "Add" on the items you need to raise a request.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Store split banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              byStore.length == 1
                                  ? 'Items will be requested from ${storeName(byStore.keys.first)}.'
                                  : 'Items are from ${byStore.length} stores. ${byStore.length} separate requests will be created automatically.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Groups by Store
                    for (final entry in byStore.entries) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              storeName(entry.key),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value.length} ${entry.value.length == 1 ? 'item' : 'items'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final line in entry.value) ...[
                        RequestSelectedItemCard(
                          line: line,
                          storeName: storeName(entry.key),
                          onRemove: () => onRemoveLine(line),
                          onQuantityChanged: onQuantityChanged,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 8),
                    IcueTextField(
                      controller: purposeController,
                      label: 'Purpose of request *',
                      hintText:
                          'e.g. Science lab experiments, classroom supplies...',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                      maxLength: 500,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: IcueButton(
                label: isSubmitting
                    ? 'Submitting...'
                    : 'Submit Request (${lines.length})',
                onPressed: isSubmitting ? null : onSubmit,
                leadingIcon: Icons.send_rounded,
                isFullWidth: true,
                isLoading: isSubmitting,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
