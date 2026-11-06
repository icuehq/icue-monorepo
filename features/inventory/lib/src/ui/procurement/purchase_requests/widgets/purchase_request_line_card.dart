import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class RequestLineDraft {
  RequestLineDraft(
    this.itemId,
    this.name, {
    String quantity = '',
    String price = '',
  }) : quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);

  final String itemId;
  final String name;
  final TextEditingController quantity;
  final TextEditingController price;

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class RequestLineCard extends StatelessWidget {
  const RequestLineCard({
    required this.line,
    required this.onRemove,
    super.key,
  });

  final RequestLineDraft line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Remove',
                color: theme.colorScheme.error,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: line.quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final quantity = double.tryParse((value ?? '').trim());
                    return quantity == null || quantity <= 0
                        ? 'Enter quantity'
                        : null;
                  },
                  label: 'Quantity *',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: line.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: optionalNumber,
                  label: 'Est. Unit Price (₹)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
