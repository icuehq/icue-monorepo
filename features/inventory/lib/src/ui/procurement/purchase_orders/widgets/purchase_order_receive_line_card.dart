import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

/// Draft inputs for one PO line being received.
class ReceiveLineDraft {
  ReceiveLineDraft(this.line);

  final OrderLine line;
  final accepted = TextEditingController();
  final rejected = TextEditingController();
  final condition = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();

  double get acceptedValue => double.tryParse(accepted.text.trim()) ?? 0;
  double get rejectedValue => double.tryParse(rejected.text.trim()) ?? 0;
  bool get touched => acceptedValue + rejectedValue > 0;

  void dispose() {
    for (final controller in [
      accepted,
      rejected,
      condition,
      batchNumber,
      expiry,
    ]) {
      controller.dispose();
    }
  }

  Map<String, Object?> toJson() {
    String? text(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return {
      'itemId': line.itemId,
      'variantId': ?line.variantId,
      'quantityAccepted': acceptedValue,
      'quantityRejected': rejectedValue,
      'condition': text(condition),
      'batchNumber': text(batchNumber),
      'expiryDate': text(expiry),
    };
  }
}

/// Card representing a single PO line receiving row.
class PurchaseOrderReceiveLineCard extends StatelessWidget {
  const PurchaseOrderReceiveLineCard({
    required this.draft,
    required this.itemName,
    required this.isBatchTracked,
    required this.onChanged,
    required this.validator,
    super.key,
  });

  final ReceiveLineDraft draft;
  final String itemName;
  final bool isBatchTracked;
  final VoidCallback onChanged;
  final String? Function(String?, ReceiveLineDraft) validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const num = TextInputType.numberWithOptions(decimal: true);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: draft.touched
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: draft.touched ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ordered ${draft.line.quantity.toQuantityText()} · Received ${draft.line.quantityReceived.toQuantityText()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Due: ${draft.line.due.toQuantityText()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.accepted,
                    keyboardType: num,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: 'Accepted',
                      prefixIcon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                      ),
                      filled: true,
                      fillColor: draft.acceptedValue > 0
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                    ),
                    validator: (value) => validator(value, draft),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: draft.rejected,
                    keyboardType: num,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: 'Rejected',
                      prefixIcon: const Icon(
                        Icons.highlight_off_rounded,
                        color: Colors.redAccent,
                      ),
                      filled: true,
                      fillColor: draft.rejectedValue > 0
                          ? Colors.red.withValues(alpha: 0.05)
                          : null,
                    ),
                    validator: (value) => validator(value, draft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: draft.condition,
              label: 'Condition / package state (optional)',
              icon: Icons.shield_outlined,
            ),
            if (isBatchTracked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: draft.batchNumber,
                            validator: (value) =>
                                draft.acceptedValue > 0 &&
                                    (value ?? '').trim().isEmpty
                                ? 'Batch required'
                                : null,
                            label: 'Batch no. *',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _expiry(context, draft)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expiry(BuildContext context, ReceiveLineDraft draft) => AppDateField(
    controller: draft.expiry,
    label: 'Expiry date *',
    firstDate: DateTime.now(),
    lastDate: DateTime(2100),
    initialDate: DateTime.now().add(const Duration(days: 180)),
    validator: (value) =>
        draft.acceptedValue > 0 && (value ?? '').trim().isEmpty
        ? 'Expiry required'
        : null,
  );
}
