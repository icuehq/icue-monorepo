import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/issue_return_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One issue request: approve/reject (approver), issue (storekeeper), then issues → return.
class RequestSheet extends StatefulWidget {
  const RequestSheet({required this.request, super.key});

  final InventoryIssueRequest request;

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _comment = TextEditingController();
  final _recipient = TextEditingController();
  late final _approve = [
    for (final requestLine in widget.request.lineItems)
      TextEditingController(text: formatQuantity(requestLine.requested)),
  ];
  final _requestId = newRequestId();
  var _recipientType = 'staff';
  late final Future<List<InventoryIssue>> _issues = widget.request.isPending
      ? Future.value([])
      : context.read<StockProvider>().issuesOf(widget.request);

  @override
  void dispose() {
    _comment.dispose();
    _recipient.dispose();
    for (final controller in _approve) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _decide(bool approve) => stockSubmit(
    context,
    (stockProvider) => stockProvider.act('inventory-issueRequest-decide', {
      'id': widget.request.id,
      'decision': approve ? 'approve' : 'reject',
      'comment': _comment.text.trim(),
      if (approve)
        'lineItems': [
          for (final (i, c) in _approve.indexed)
            {
              'index': i,
              'quantityApproved': double.tryParse(c.text.trim()) ?? 0,
            },
        ],
    }, requestId: _requestId),
    done: approve ? 'Approved' : 'Rejected',
  );

  Future<void> _issue() async {
    final personErpId = int.tryParse(_recipient.text.trim());
    if (personErpId == null) {
      return showMessage(context, 'Enter the recipient ERP ID');
    }
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-issue-create', {
        'issueRequestId': widget.request.id,
        'recipient': {'type': _recipientType, 'personErpId': personErpId},
        'lineItems': [
          for (final requestLine in widget.request.lineItems)
            if ((requestLine.approved ?? 0) - requestLine.issued > 0)
              {
                'itemId': requestLine.itemId,
                'variantId': ?requestLine.variantId,
                'quantity': (requestLine.approved ?? 0) - requestLine.issued,
              },
        ],
      }, requestId: _requestId),
      done: 'Issued',
    );
  }

  @override
  Widget build(BuildContext context) {
    final issueRequest = widget.request;
    final stockProvider = context.read<StockProvider>();
    final access = context.read<InventoryProvider>().access;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          issueRequest.number,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${humanizeStatus(issueRequest.status)} · ${issueRequest.purpose}',
        ),
        if (issueRequest.approvalComment != null &&
            issueRequest.approvalComment!.isNotEmpty)
          Text('Comment: ${issueRequest.approvalComment}'),
        const SizedBox(height: 8),
        for (final (i, l) in issueRequest.lineItems.indexed)
          issueRequest.isPending && access.can('inventory.issue.approve')
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _approve[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${stockProvider.itemName(l.itemId)} – approve (requested ${formatQuantity(l.requested)})',
                    ),
                  ),
                )
              : ListTile(
                  dense: true,
                  title: Text(stockProvider.itemName(l.itemId)),
                  trailing: Text(
                    'Req ${formatQuantity(l.requested)}'
                    '${l.approved == null ? '' : ' · Appr ${formatQuantity(l.approved!)}'}'
                    '${l.issued > 0 ? ' · Issued ${formatQuantity(l.issued)}' : ''}',
                  ),
                ),
        if (issueRequest.isPending &&
            access.can('inventory.issue.approve')) ...[
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
        if (issueRequest.isIssuable &&
            access.can('inventory.stock.operate')) ...[
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
                onChanged: (value) => setState(() => _recipientType = value!),
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
        if (!issueRequest.isPending && access.can('inventory.stock.operate'))
          FutureBuilder<List<InventoryIssue>>(
            future: _issues,
            builder: (context, snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((snapshot.data ?? []).isNotEmpty) const Divider(),
                for (final i in snapshot.data ?? <InventoryIssue>[])
                  ListTile(
                    dense: true,
                    title: Text(i.number),
                    subtitle: Text(
                      i.acknowledged
                          ? 'Receipt confirmed'
                          : 'Awaiting recipient confirmation',
                    ),
                    trailing: TextButton(
                      onPressed: () => showFormSheet(
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
