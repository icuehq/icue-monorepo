import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/receipt_line_fields.dart';
import 'package:inventory/src/ui/stock/shared/stock_validators.dart';

/// One editable stock line. Controllers live here so the editor can rebuild freely.
class LineDraft {
  LineDraft(this.item, this.variant);

  final InventoryItem item;
  final InventoryVariant? variant;
  final quantity = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    for (final controller in [quantity, batchNumber, expiry, cost]) {
      controller.dispose();
    }
  }

  /// Request payload; only the fields the screen asked for are sent.
  Map<String, Object?> toMap({
    String quantityKey = 'quantity',
    bool batch = false,
    bool receipt = false,
  }) {
    String? text(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return {
      'itemId': item.id,
      'variantId': ?variant?.id,
      quantityKey: double.tryParse(quantity.text.trim()) ?? 0,
      if (receipt) 'unitCost': ?double.tryParse(cost.text.trim()),
      if (batch && item.tracking == Tracking.batch) ...{
        'batchNumber': text(batchNumber),
        'expiryDate': text(expiry),
      },
    };
  }
}

/// Add/remove item lines with quantity (and optionally receipt/batch fields).
class LineEditor extends StatelessWidget {
  const LineEditor({
    required this.lineItems,
    required this.onChanged,
    this.quantityLabel = 'Quantity',
    this.receipt = false,
    super.key,
  });

  final List<LineDraft> lineItems;
  final VoidCallback onChanged;
  final String quantityLabel;

  /// Show rejected quantity, unit cost, batch number and expiry.
  final bool receipt;

  Future<void> _addItem(BuildContext context) async {
    final picked = await pickItem(context);
    if (picked == null) return;
    final draft = LineDraft(picked.item, picked.variant);
    if (receipt &&
        picked.item.defaultPrice != null &&
        picked.item.defaultPrice! > 0) {
      draft.cost.text = picked.item.defaultPrice!.toAmountText();
    }
    lineItems.add(draft);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lineItems.isEmpty) {
      final color = theme.colorScheme.primary;
      return InkWell(
        onTap: () => _addItem(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(Icons.add_rounded, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                'Add item',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                receipt
                    ? 'Pick the items you are adding to the store'
                    : 'Add items and specify the quantities',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, lineDraft) in lineItems.indexed)
          _LineCard(
            lineDraft: lineDraft,
            receipt: receipt,
            quantityLabel: quantityLabel,
            onRemove: () {
              lineItems.removeAt(index).dispose();
              onChanged();
            },
          ),
        IcueButton(
          label: 'Add another item',
          onPressed: () => _addItem(context),
          variant: IcueButtonVariant.outline,
          leadingIcon: Icons.add_rounded,
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.lineDraft,
    required this.receipt,
    required this.quantityLabel,
    required this.onRemove,
  });

  final LineDraft lineDraft;
  final bool receipt;
  final String quantityLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = lineDraft.item;
    final variant = lineDraft.variant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (variant != null)
                          _TagBadge(
                            label: variant.attrs.isNotEmpty
                                ? variant.attrs.values.join(' · ')
                                : variant.sku,
                            color: theme.colorScheme.primary,
                            backgroundColor: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.35),
                          ),
                        if (item.stockUnit.isNotEmpty)
                          _TagBadge(label: 'Unit: ${item.stockUnit}'),
                        if (item.tracking == Tracking.batch)
                          _TagBadge(
                            label: 'Batch tracked',
                            color: theme.colorScheme.tertiary,
                            backgroundColor: theme.colorScheme.tertiaryContainer
                                .withValues(alpha: 0.35),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Remove item',
                color: theme.colorScheme.error,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (receipt) ...[
            ReceiptLineFields(lineDraft: lineDraft),
          ] else ...[
            IcueTextField(
              controller: lineDraft.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: quantityFormatters,
              validator: validateQuantity,
              label: quantityLabel,
              icon: Icons.numbers_rounded,
              suffixText: item.stockUnit.isNotEmpty ? item.stockUnit : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, this.color, this.backgroundColor});

  final String label;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IcueStatusPill(
      label: label,
      color: color ?? scheme.onSurfaceVariant,
      background:
          backgroundColor ??
          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      bordered: false,
    );
  }
}
