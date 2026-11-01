import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Confirm receipt of an issue, or record a return with inspection split usable / damaged (FRS 10.9).
class IssueReturnSheet extends StatefulWidget {
  const IssueReturnSheet({required this.issue, super.key});

  final InvIssue issue;

  @override
  State<IssueReturnSheet> createState() => _IssueReturnSheetState();
}

class _IssueReturnSheetState extends State<IssueReturnSheet> {
  late final _usable = [
    for (final _ in widget.issue.lines) TextEditingController(),
  ];
  late final _damaged = [
    for (final _ in widget.issue.lines) TextEditingController(),
  ];
  final _returnedBy = TextEditingController();
  final _requestId = newRequestId();

  @override
  void dispose() {
    _returnedBy.dispose();
    for (final c in [..._usable, ..._damaged]) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _return() async {
    final erpId = int.tryParse(_returnedBy.text.trim());
    if (erpId == null) {
      return invSnack(context, 'Enter the returning person\'s ERP ID');
    }
    final lines = [
      for (final (i, l) in widget.issue.lines.indexed)
        if (_v(_usable[i]) + _v(_damaged[i]) > 0)
          {
            'balanceId': l.balanceId,
            'qtyUsable': _v(_usable[i]),
            'qtyDamaged': _v(_damaged[i]),
          },
    ];
    if (lines.isEmpty) return invSnack(context, 'Enter a returned quantity');
    await stockSubmit(
      context,
      (p) => p.act('inv-return-create', {
        'issueId': widget.issue.id,
        'returnedBy': {'type': 'staff', 'erpId': erpId},
        'lines': lines,
      }, requestId: _requestId),
      done: 'Return recorded',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<StockProvider>();
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
              (p) => p.act('inv-issue-acknowledge', {'id': issue.id}),
              done: 'Receipt confirmed',
            ),
          ),
        const Divider(),
        const Text('Return (inspect: usable vs damaged)'),
        for (final (i, l) in issue.lines.indexed)
          if (l.outstanding > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${p.itemName(l.itemId)}${l.batchNo == null ? '' : ' · ${l.batchNo}'}\nOutstanding ${fmtQty(l.outstanding)}',
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
