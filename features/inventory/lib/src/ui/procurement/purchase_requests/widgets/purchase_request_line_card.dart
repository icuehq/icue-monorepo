import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class RequestLineDraft {
  RequestLineDraft(
    this.itemId,
    this.name, {
    this.variantId,
    this.unit = '',
    String quantity = '',
  }) : quantity = TextEditingController(text: quantity);

  final String itemId;
  final String? variantId;
  final String name;
  final String unit;
  final TextEditingController quantity;

  void dispose() {
    quantity.dispose();
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

  Widget _quantityField(String label) => IcueTextField(
    controller: line.quantity,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [decimalInputFormatter],
    textInputAction: TextInputAction.next,
    validator: (value) {
      final quantity = double.tryParse((value ?? '').trim());
      return quantity == null || quantity <= 0 ? 'Enter quantity' : null;
    },
    label: label,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stackedLabel = line.unit.isNotEmpty
        ? 'Quantity (${line.unit}) *'
        : 'Quantity *';

    final removeButton = IconButton(
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      tooltip: 'Remove item',
      color: theme.colorScheme.error,
      onPressed: onRemove,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inlineLayout = constraints.maxWidth >= 460;
          if (inlineLayout) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (line.unit.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Unit: ${line.unit}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: _quantityField('Quantity *')),
                const SizedBox(width: 4),
                removeButton,
              ],
            );
          }

          return Column(
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
                  removeButton,
                ],
              ),
              const SizedBox(height: 8),
              _quantityField(stackedLabel),
            ],
          );
        },
      ),
    );
  }
}
