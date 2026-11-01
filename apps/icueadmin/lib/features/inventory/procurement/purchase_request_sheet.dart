import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
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

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _act(String value, Map<String, Object?> extra, String done) =>
      procSubmit(
        context,
        (procurementProvider) =>
            procurementProvider.act(value, {'id': widget.request.id, ...extra}),
        done: done,
      );

  Future<void> _decide(String decision, String done) => _act(
    'inventory-purchaseRequest-decide',
    {'decision': decision, 'comment': _comment.text.trim()},
    done,
  );

  Future<void> _go(String route, Object extra) async {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    await router.push(route, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final purchaseRequest = widget.request;
    final procurementProvider = context.read<ProcurementProvider>();
    final access = context.read<InventoryProvider>().access;
    final isOwnRequest = purchaseRequest.createdBy == procurementProvider.uid;
    final decides =
        purchaseRequest.isPending &&
        access.can('inventory.purchaseRequest.approve');
    final cancel = isOwnRequest && purchaseRequest.isCancellable;
    final buy =
        access.can('inventory.procure.operate') && purchaseRequest.isOrderable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          purchaseRequest.number,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${humanizeStatus(purchaseRequest.status)} · ${humanizeStatus(purchaseRequest.priority)} priority · '
          'needed by ${purchaseRequest.requiredDate}',
        ),
        Text(purchaseRequest.purpose),
        if (purchaseRequest.remarks != null &&
            purchaseRequest.remarks!.isNotEmpty)
          Text(purchaseRequest.remarks!),
        const SizedBox(height: 8),
        for (final purchaseRequestLine in purchaseRequest.lineItems)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              procurementProvider.itemName(purchaseRequestLine.itemId),
            ),
            trailing: Text(
              '${formatQuantity(purchaseRequestLine.quantity)} × ${formatQuantity(purchaseRequestLine.estimatedPrice)}'
              '${purchaseRequestLine.quantityOrdered > 0 ? ' · ordered ${formatQuantity(purchaseRequestLine.quantityOrdered)}' : ''}',
            ),
          ),
        Text('Estimated total: ${formatQuantity(purchaseRequest.total)}'),
        if (purchaseRequest.history.isNotEmpty) ...[
          const Divider(),
          for (final purchaseRequestHistory in purchaseRequest.history)
            Text(
              '${purchaseRequestHistory.performedAt?.toString().substring(0, 16) ?? ''} · '
              '${humanizeStatus(purchaseRequestHistory.action)}'
              '${purchaseRequestHistory.comment == null ? '' : ': ${purchaseRequestHistory.comment}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (decides || cancel) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            decoration: InputDecoration(
              labelText: decides
                  ? 'Comment (required to reject or return)'
                  : 'Reason (optional)',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (decides) ...[
              FilledButton(
                onPressed: () => _decide('approve', 'Approved'),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: () => _decide('revise', 'Returned'),
                child: const Text('Return for revision'),
              ),
              OutlinedButton(
                onPressed: () => _decide('reject', 'Rejected'),
                child: const Text('Reject'),
              ),
            ],
            if (isOwnRequest && purchaseRequest.isEditable) ...[
              FilledButton(
                onPressed: () =>
                    _act('inventory-purchaseRequest-submit', {}, 'Submitted'),
                child: const Text('Submit for approval'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await context.push(
                    AppRoutes.inventoryPurchaseRequestForm,
                    extra: purchaseRequest,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Edit'),
              ),
            ],
            if (buy) ...[
              OutlinedButton(
                onPressed: () =>
                    _go(AppRoutes.inventoryQuotations, purchaseRequest),
                child: const Text('Quotations'),
              ),
              OutlinedButton(
                onPressed: () => _go(AppRoutes.inventoryPurchaseOrderForm, (
                  purchaseRequest,
                  null,
                  null,
                )),
                child: const Text('Create PO'),
              ),
            ],
            if (cancel)
              TextButton(
                onPressed: () => _act('inventory-purchaseRequest-cancel', {
                  'reason': _comment.text.trim(),
                }, 'Cancelled'),
                child: const Text('Cancel request'),
              ),
          ],
        ),
      ],
    );
  }
}
