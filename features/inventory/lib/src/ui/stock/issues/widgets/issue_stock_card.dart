import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_widgets.dart';

/// Storekeeper step: how much of each approved line leaves now to the requester.
class IssueStockCard extends StatelessWidget {
  const IssueStockCard({
    required this.request,
    required this.itemName,
    required this.quantityControllers,
    super.key,
  });

  final InventoryIssueRequest request;
  final String Function(String itemId) itemName;

  /// One controller per request line, holding the quantity to issue now.
  final List<TextEditingController> quantityControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requesterId = int.tryParse(request.createdBy);
    return IssueSection(
      title: 'Issue stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            avatar: const Icon(Icons.person_rounded, size: 18),
            label: Text(
              requesterId == null
                  ? 'Staff #${request.createdBy} · requester'
                  : '${staffDisplayName(requesterId)} · requester',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Quantity to issue now',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final (index, line) in request.lineItems.indexed)
            if (remainingToIssue(line) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IcueTextField(
                  controller: quantityControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalInputFormatter],
                  label: itemName(line.itemId),
                  helperText:
                      'Remaining ${remainingToIssue(line).toQuantityText()} of '
                      '${(line.approved ?? 0).toQuantityText()} approved',
                ),
              ),
        ],
      ),
    );
  }
}

/// Approved but not yet issued.
double remainingToIssue(RequestLine line) => (line.approved ?? 0) - line.issued;
