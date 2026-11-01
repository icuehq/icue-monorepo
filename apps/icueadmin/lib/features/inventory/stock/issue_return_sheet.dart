import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Confirm receipt of an issue, or record a return with inspection split usable / damaged (FRS 10.9).
class IssueReturnSheet extends StatefulWidget {
  const IssueReturnSheet({required this.issue, super.key});

  final InventoryIssue issue;

  @override
  State<IssueReturnSheet> createState() => _IssueReturnSheetState();
}

class _IssueReturnSheetState extends State<IssueReturnSheet> {
  late final _usable = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  late final _damaged = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  final _returnedBy = TextEditingController();
  final _requestId = newRequestId();

  @override
  void dispose() {
    _returnedBy.dispose();
    for (final controller in [..._usable, ..._damaged]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _return() async {
    final personErpId = int.tryParse(_returnedBy.text.trim());
    if (personErpId == null) {
      return showMessage(context, 'Enter the returning person\'s ERP ID');
    }
    final lineItems = [
      for (final (i, l) in widget.issue.lineItems.indexed)
        if (_v(_usable[i]) + _v(_damaged[i]) > 0)
          {
            'balanceId': l.balanceId,
            'quantityUsable': _v(_usable[i]),
            'quantityDamaged': _v(_damaged[i]),
          },
    ];
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter a returned quantity');
    }
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-return-create', {
        'issueId': widget.issue.id,
        'returnedBy': {'type': 'staff', 'personErpId': personErpId},
        'lineItems': lineItems,
      }, requestId: _requestId),
      done: 'Return recorded',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStockProvider = context.read<StockProvider>();
    final issue = widget.issue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(issue.number, style: Theme.of(context).textTheme.titleLarge),
        if (!issue.acknowledged)
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Recipient has received the items'),
            onPressed: () => stockSubmit(
              context,
              (stockProvider) => stockProvider.act(
                'inventory-issue-acknowledge',
                {'id': issue.id},
              ),
              done: 'Receipt confirmed',
            ),
          ),
        const Divider(),
        const Text('Return (inspect: usable vs damaged)'),
        for (final (i, l) in issue.lineItems.indexed)
          if (l.outstanding > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${currentStockProvider.itemName(l.itemId)}${l.batchNumber == null ? '' : ' · ${l.batchNumber}'}\nOutstanding ${formatQuantity(l.outstanding)}',
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _usable[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Usable'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _damaged[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Damaged'),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        TextField(
          controller: _returnedBy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Returned by (staff ERP ID)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _return, child: const Text('Record return')),
      ],
    );
  }
}
