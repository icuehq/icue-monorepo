import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One purchase request: lines, approval history, and the actions the caller may take.
class PurchaseRequestSheet extends StatefulWidget {
  const PurchaseRequestSheet({required this.request, super.key});

  final InventoryPurchaseRequest request;

  @override
  State<PurchaseRequestSheet> createState() => _PurchaseRequestSheetState();
}

class _PurchaseRequestSheetState extends State<PurchaseRequestSheet> {
  final _comment = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _act(
    String value,
    Map<String, Object?> extra,
    String done,
  ) async {
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act(value, {'id': widget.request.id, ...extra}),
      done: done,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _decide(String decision, String done) {
    if ((decision == 'reject' || decision == 'revise') &&
        _comment.text.trim().isEmpty) {
      showMessage(context, 'Please enter a comment explaining the $decision');
      return Future.value();
    }
    return _act('inventory-purchaseRequest-decide', {
      'decision': decision,
      'comment': _comment.text.trim(),
    }, done);
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: Text(
          'Are you sure you want to cancel ${widget.request.number}? This request will be closed permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await _act('inventory-purchaseRequest-cancel', {
      'reason': _comment.text.trim(),
    }, 'Request cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchaseRequest = widget.request;
    final procurementProvider = context.read<ProcurementProvider>();
    final access = context.read<InventoryProvider>().access;

    final isOwnRequest = purchaseRequest.createdBy == procurementProvider.uid;
    final decides =
        purchaseRequest.isPending &&
        access.can('inventory.purchaseRequest.approve');
    final canCancel = isOwnRequest && purchaseRequest.isCancellable;
    final canProcure =
        access.can('inventory.procure.operate') && purchaseRequest.isOrderable;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Number, Campus, Status & Priority
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchaseRequest.number,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Campus ${purchaseRequest.campusId} · Needed by ${purchaseRequest.requiredDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(humanizeStatus(purchaseRequest.status)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Purpose Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchaseRequest.purpose,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (purchaseRequest.remarks != null &&
                    purchaseRequest.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    purchaseRequest.remarks!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items List
          Text(
            'Requested Items',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in purchaseRequest.lineItems)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            procurementProvider.itemName(line.itemId),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${formatQuantity(line.quantity)} units @ ₹${formatQuantity(line.estimatedPrice)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${formatQuantity(line.quantity * line.estimatedPrice)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (line.quantityOrdered > 0)
                          Text(
                            'Ordered: ${formatQuantity(line.quantityOrdered)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total Estimated: ₹${formatQuantity(purchaseRequest.total)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // History Section
          if (purchaseRequest.history.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Approval & Revision History',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in purchaseRequest.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _historyIcon(entry.action),
                            size: 16,
                            color: _historyColor(entry.action),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  humanizeStatus(entry.action),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (entry.comment != null &&
                                    entry.comment!.isNotEmpty)
                                  Text(
                                    entry.comment!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          if (entry.performedAt != null)
                            Text(
                              entry.performedAt.toString().substring(0, 10),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Comments input (for approver decision or cancellation)
          if (decides || canCancel) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              decoration: InputDecoration(
                labelText: decides
                    ? 'Approver Comment (required for reject / return)'
                    : 'Cancellation reason (optional)',
                hintText: decides ? 'e.g. Approved as per Q2 budget' : null,
                prefixIcon: const Icon(Icons.comment_outlined),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Actions
          if (decides) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _decide('approve', 'Approved successfully'),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _decide('revise', 'Returned for revision'),
                    child: const Text('Return for Revision'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _decide('reject', 'Request rejected'),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],

          if (isOwnRequest && purchaseRequest.isEditable) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            'inventory-purchaseRequest-submit',
                            {},
                            'Submitted for approval',
                          ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Submit for Approval'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    await router.push(
                      AppRoutes.inventoryPurchaseRequestForm,
                      extra: purchaseRequest,
                    );
                  },
                ),
              ],
            ),
          ],

          if (canProcure) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push(
                        AppRoutes.inventoryQuotations,
                        extra: purchaseRequest,
                      );
                    },
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Quotations'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push(
                        AppRoutes.inventoryPurchaseOrderForm,
                        extra: (purchaseRequest, null, null),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: const Text('Direct PO'),
                  ),
                ),
              ],
            ),
          ],

          if (canCancel) ...[
            const SizedBox(height: 8),
            Align(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Request'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _historyIcon(String action) {
    switch (action) {
      case 'approve':
        return Icons.check_circle_rounded;
      case 'reject':
        return Icons.cancel_rounded;
      case 'revise':
        return Icons.replay_rounded;
      case 'cancel':
        return Icons.block_rounded;
      default:
        return Icons.fiber_manual_record_rounded;
    }
  }

  Color _historyColor(String action) {
    switch (action) {
      case 'approve':
        return Colors.green;
      case 'reject':
        return Colors.red;
      case 'revise':
        return Colors.orange;
      case 'cancel':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
