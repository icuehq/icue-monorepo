import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';

/// One editable stock line. Controllers live here so the editor can rebuild freely.
class LineDraft {
  LineDraft(this.item, this.variant);

  final InventoryItem item;
  final InventoryVariant? variant;
  final quantity = TextEditingController();
  final rejected = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    for (final controller in [quantity, rejected, batchNumber, expiry, cost]) {
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
      if (receipt)
        'quantityRejected': double.tryParse(rejected.text.trim()) ?? 0,
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.25,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(
              receipt
                  ? Icons.move_to_inbox_rounded
                  : Icons.inventory_2_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              receipt ? 'No items to receive' : 'No items added',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              receipt
                  ? 'Select items to receive them into the chosen store'
                  : 'Add items and specify the quantities',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add item'),
              onPressed: () => _addItem(context),
            ),
          ],
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
        const SizedBox(height: 4),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add another item'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _addItem(context),
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
                        if (item.code.isNotEmpty)
                          _TagBadge(label: '#${item.code}'),
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
            // Row 1: Quantities
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: lineDraft.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Accepted',
                      hintText: '0',
                      prefixIcon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                      ),
                      suffixText: item.stockUnit.isNotEmpty
                          ? item.stockUnit
                          : null,
                    ),
                    validator: (currentValue) {
                      final value = (currentValue ?? '').trim();
                      if (value.isEmpty) return 'Required';
                      final number = double.tryParse(value);
                      if (number == null || number <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: lineDraft.rejected,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Rejected (optional)',
                      hintText: '0',
                      prefixIcon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.redAccent,
                      ),
                      suffixText: item.stockUnit.isNotEmpty
                          ? item.stockUnit
                          : null,
                    ),
                    validator: (currentValue) {
                      final value = (currentValue ?? '').trim();
                      if (value.isEmpty) return null;
                      final number = double.tryParse(value);
                      if (number == null || number < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Unit cost & line subtotal
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: lineDraft.cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (currentValue) {
                      final value = (currentValue ?? '').trim();
                      if (value.isEmpty) return null;
                      final number = double.tryParse(value);
                      if (number == null || number < 0) return 'Invalid';
                      return null;
                    },
                    label: 'Unit cost (₹)',
                    hintText:
                        item.defaultPrice != null && item.defaultPrice! > 0
                        ? item.defaultPrice!.toAmountText()
                        : '0.00',
                    icon: Icons.currency_rupee_rounded,
                    helperText: item.stockUnit.isNotEmpty
                        ? 'Per ${item.stockUnit}'
                        : 'Per unit',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      lineDraft.quantity,
                      lineDraft.cost,
                    ]),
                    builder: (context, _) {
                      final accepted =
                          double.tryParse(lineDraft.quantity.text.trim()) ?? 0;
                      final unitCost =
                          double.tryParse(lineDraft.cost.text.trim()) ?? 0;
                      final hasCalculation = accepted > 0 && unitCost > 0;
                      final subtotal = accepted * unitCost;

                      return Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: hasCalculation
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasCalculation
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  )
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Line Subtotal',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasCalculation ? subtotal.toRupees() : '—',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasCalculation
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (item.tracking == Tracking.batch) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Batch Tracking',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: lineDraft.batchNumber,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Required'
                                : null,
                            label: 'Batch number',
                            icon: Icons.tag_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppDateField(
                            controller: lineDraft.expiry,
                            label: 'Expiry date',
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                            validator: (value) =>
                                (value ?? '').compareTo(
                                          DateTime.now().toApiDate(),
                                        ) <
                                        0 &&
                                    (value ?? '').isNotEmpty
                                ? 'Expired batches cannot be received'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            AppTextField(
              controller: lineDraft.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (currentValue) {
                final value = (currentValue ?? '').trim();
                if (value.isEmpty) return 'Required';
                final number = double.tryParse(value);
                return number == null || number <= 0 ? 'Invalid' : null;
              },
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
    final theme = Theme.of(context);
    final foregroundColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
