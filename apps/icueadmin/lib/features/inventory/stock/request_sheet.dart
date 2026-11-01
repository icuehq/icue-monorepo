import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/issue_return_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One issue request: approve/reject (approver), issue (storekeeper), then issues → return.
class RequestSheet extends StatefulWidget {
  const RequestSheet({required this.request, super.key});

  final InvIssueRequest request;

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _comment = TextEditingController();
  final _recipient = TextEditingController();
  late final _approve = [
    for (final l in widget.request.lines)
      TextEditingController(text: fmtQty(l.requested)),
  ];
  final _requestId = newRequestId();
  var _recipientType = 'staff';
  late final Future<List<InvIssue>> _issues = widget.request.isPending
      ? Future.value([])
      : context.read<StockProvider>().issuesOf(widget.request);

  @override
  void dispose() {
    _comment.dispose();
    _recipient.dispose();
    for (final c in _approve) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _decide(bool approve) => stockSubmit(
    context,
    (p) => p.act('inv-issueRequest-decide', {
      'id': widget.request.id,
      'decision': approve ? 'approve' : 'reject',
      'comment': _comment.text.trim(),
      if (approve)
        'lines': [
          for (final (i, c) in _approve.indexed)
            {'index': i, 'qtyApproved': double.tryParse(c.text.trim()) ?? 0},
        ],
    }, requestId: _requestId),
    done: approve ? 'Approved' : 'Rejected',
  );

  Future<void> _issue() async {
    final erpId = int.tryParse(_recipient.text.trim());
    if (erpId == null) return invSnack(context, 'Enter the recipient ERP ID');
    await stockSubmit(
      context,
      (p) => p.act('inv-issue-create', {
        'issueRequestId': widget.request.id,
        'recipient': {'type': _recipientType, 'erpId': erpId},
        'lines': [
          for (final l in widget.request.lines)
            if ((l.approved ?? 0) - l.issued > 0)
              {
                'itemId': l.itemId,
                'variantId': ?l.variantId,
                'qty': (l.approved ?? 0) - l.issued,
              },
        ],
      }, requestId: _requestId),
      done: 'Issued',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final p = context.read<StockProvider>();
    final a = context.read<InventoryProvider>().access;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.number, style: Theme.of(context).textTheme.titleLarge),
        Text('${statusLabel(r.status)} · ${r.purpose}'),
        if (r.approvalComment != null && r.approvalComment!.isNotEmpty)
          Text('Comment: ${r.approvalComment}'),
        const SizedBox(height: 8),
        for (final (i, l) in r.lines.indexed)
          r.isPending && a.can('inv.issue.approve')
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _approve[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${p.itemName(l.itemId)} – approve (requested ${fmtQty(l.requested)})',
                    ),
                  ),
                )
              : ListTile(
                  dense: true,
                  title: Text(p.itemName(l.itemId)),
                  trailing: Text(
                    'Req ${fmtQty(l.requested)}'
                    '${l.approved == null ? '' : ' · Appr ${fmtQty(l.approved!)}'}'
                    '${l.issued > 0 ? ' · Issued ${fmtQty(l.issued)}' : ''}',
                  ),
                ),
        if (r.isPending && a.can('inv.issue.approve')) ...[
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Comment (required to reject)',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _decide(false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _decide(true),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
        if (r.isIssuable && a.can('inv.stock.operate')) ...[
          const Divider(),
          Row(
            children: [
              DropdownButton<String>(
                value: _recipientType,
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'department', child: Text('Dept')),
                ],
                onChanged: (v) => setState(() => _recipientType = v!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _recipient,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Recipient ERP ID',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _issue,
            child: const Text('Issue remaining approved quantity'),
          ),
        ],
        if (!r.isPending && a.can('inv.stock.operate'))
          FutureBuilder<List<InvIssue>>(
            future: _issues,
            builder: (context, snap) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((snap.data ?? []).isNotEmpty) const Divider(),
                for (final i in snap.data ?? <InvIssue>[])
                  ListTile(
                    dense: true,
                    title: Text(i.number),
                    subtitle: Text(
                      i.acknowledged
                          ? 'Receipt confirmed'
                          : 'Awaiting recipient confirmation',
                    ),
                    trailing: TextButton(
                      onPressed: () => showInvSheet(
                        context,
                        () => IssueReturnSheet(issue: i),
                      ),
                      child: const Text('Return / confirm'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
