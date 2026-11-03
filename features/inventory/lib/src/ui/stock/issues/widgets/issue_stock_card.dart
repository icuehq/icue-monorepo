import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_widgets.dart';

/// Storekeeper step: who receives the stock and how much of each approved line leaves now.
class IssueStockCard extends StatelessWidget {
  const IssueStockCard({
    required this.request,
    required this.itemName,
    required this.quantityControllers,
    required this.recipientType,
    required this.recipientId,
    required this.onRecipientType,
    required this.onRecipient,
    super.key,
  });

  final InventoryIssueRequest request;
  final String Function(String itemId) itemName;

  /// One controller per request line, holding the quantity to issue now.
  final List<TextEditingController> quantityControllers;
  final String recipientType;
  final int? recipientId;
  final ValueChanged<String> onRecipientType;
  final ValueChanged<int?> onRecipient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipient = recipientId;
    return IssueSection(
      title: 'Issue stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'staff', label: Text('Staff')),
              ButtonSegment(value: 'student', label: Text('Student')),
              ButtonSegment(value: 'department', label: Text('Department')),
            ],
            selected: {recipientType},
            onSelectionChanged: (selection) => onRecipientType(selection.first),
          ),
          const SizedBox(height: 12),
          if (recipient != null)
            InputChip(
              avatar: const Icon(Icons.person_rounded, size: 18),
              label: Text(
                '${recipientType == 'staff' ? staffDisplayName(recipient) : '$recipientType #$recipient'}'
                '${recipient.toString() == request.createdBy ? ' · requester' : ''}',
              ),
              onDeleted: () => onRecipient(null),
            )
          else
            PersonSearchField(
              label: 'Issue to',
              hint: 'Search by name or enter an ID…',
              onSelected: (person) => onRecipient(person.id),
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
                child: TextFormField(
                  controller: quantityControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalInputFormatter],
                  decoration: InputDecoration(
                    labelText: itemName(line.itemId),
                    helperText:
                        'Remaining ${remainingToIssue(line).toQuantityText()} of '
                        '${(line.approved ?? 0).toQuantityText()} approved',
                    isDense: true,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Approved but not yet issued.
double remainingToIssue(RequestLine line) => (line.approved ?? 0) - line.issued;
