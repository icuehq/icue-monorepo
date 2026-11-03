import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/issue_return_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/person_search_field.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

Color _statusColor(String status) => switch (status) {
  'approved' => Colors.blue.shade700,
  'partially_issued' => Colors.purple.shade700,
  'issued' => Colors.green.shade700,
  'rejected' => Colors.red.shade700,
  _ => Colors.orange.shade800,
};

Color _statusBgColor(String status) => switch (status) {
  'approved' => Colors.blue.withValues(alpha: 0.12),
  'partially_issued' => Colors.purple.withValues(alpha: 0.12),
  'issued' => Colors.green.withValues(alpha: 0.12),
  'rejected' => Colors.red.withValues(alpha: 0.12),
  _ => Colors.orange.withValues(alpha: 0.12),
};

/// One issue request: approve/reject (approver), issue (storekeeper), then issues → return.
class RequestSheet extends StatefulWidget {
  const RequestSheet({required this.request, super.key});

  final InventoryIssueRequest request;

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _comment = TextEditingController();
  late int? _recipientId = int.tryParse(widget.request.createdBy);
  late final _approve = [
    for (final requestLine in widget.request.lineItems)
      TextEditingController(text: formatQuantity(requestLine.requested)),
  ];
  final _requestId = newRequestId();
  var _recipientType = 'staff';
  String? _error;
  late final Future<List<InventoryIssue>> _issues = widget.request.isPending
      ? Future.value([])
      : context.read<StockProvider>().issuesOf(widget.request);

  @override
  void dispose() {
    _comment.dispose();
    for (final controller in _approve) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showFailure(bool succeeded) {
    if (!mounted) return;
    setState(
      () => _error = succeeded
          ? null
          : context.read<StockProvider>().errorMessage,
    );
  }

  Future<void> _decide(bool approve) async {
    if (!approve && _comment.text.trim().isEmpty) {
      return showMessage(context, 'Please enter a rejection comment');
    }
    _showFailure(
      await stockSubmit(
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
      ),
    );
  }

  Future<void> _approveAllInFull() {
    for (final (i, requestLine) in widget.request.lineItems.indexed) {
      _approve[i].text = formatQuantity(requestLine.requested);
    }
    return _decide(true);
  }

  Future<void> _issue() async {
    final personErpId = _recipientId;
    if (personErpId == null) {
      return showMessage(context, 'Enter the recipient ERP ID');
    }
    _showFailure(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issueRequest = widget.request;
    final stockProvider = context.read<StockProvider>();
    final access = context.read<InventoryProvider>().access;
    final theme = Theme.of(context);
    final statusColor = _statusColor(issueRequest.status);
    final statusBg = _statusBgColor(issueRequest.status);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issueRequest.number,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      issueRequest.purpose,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (issueRequest.destination != null &&
                        issueRequest.destination!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Destination: ${issueRequest.destination}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  humanizeStatus(issueRequest.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (issueRequest.approvalComment != null &&
              issueRequest.approvalComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Approval note: ${issueRequest.approvalComment}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const Divider(height: 24),

          // Requested Items Section
          Text(
            'Requested Items',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          for (final (i, l) in issueRequest.lineItems.indexed) ...[
            if (issueRequest.isPending && access.can('inventory.issue.approve'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stockProvider.itemName(l.itemId),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _approve[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [decimalInputFormatter],
                        decoration: InputDecoration(
                          labelText: 'Approved quantity',
                          helperText:
                              'Requested: ${formatQuantity(l.requested)}',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stockProvider.itemName(l.itemId),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Req: ${formatQuantity(l.requested)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (l.approved != null)
                          Text(
                            'Appr: ${formatQuantity(l.approved!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (l.issued > 0)
                          Text(
                            'Issued: ${formatQuantity(l.issued)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],

          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          // Approver Actions
          if (issueRequest.isPending &&
              access.can('inventory.issue.approve')) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              decoration: const InputDecoration(
                labelText: 'Comment / Reason (required to reject)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _approveAllInFull,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],

          // Storekeeper Issuance Action
          if (issueRequest.isIssuable &&
              access.can('inventory.stock.operate')) ...[
            const Divider(height: 24),
            Text(
              'Issue Items',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _recipientType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'department',
                        child: Text('Dept'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _recipientType = value!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PersonSearchField(
                    label: 'Recipient',
                    onSelected: (person) =>
                        setState(() => _recipientId = person.id),
                  ),
                ),
              ],
            ),
            if (_recipientId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Issuing to: ${staffDisplayName(_recipientId!)}'
                  '${_recipientId.toString() == issueRequest.createdBy ? ' (requester)' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _issue,
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: const Text('Issue approved stock'),
              ),
            ),
          ],

          // Past Issuance Records & Acknowledgements
          if (!issueRequest.isPending && access.can('inventory.stock.operate'))
            FutureBuilder<List<InventoryIssue>>(
              future: _issues,
              builder: (context, snapshot) {
                final issues = snapshot.data ?? <InventoryIssue>[];
                if (issues.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 24),
                    Text(
                      'Issuances (${issues.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final issue in issues)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    issue.number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    issue.acknowledged
                                        ? 'Receipt confirmed'
                                        : 'Awaiting confirmation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: issue.acknowledged
                                          ? Colors.green.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => showFormSheet(
                                context,
                                () => IssueReturnSheet(issue: issue),
                              ),
                              icon: const Icon(Icons.undo_rounded, size: 16),
                              label: const Text('Return'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
