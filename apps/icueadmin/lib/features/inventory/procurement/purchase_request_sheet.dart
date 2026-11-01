import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One purchase request: lines, approval history, and the actions the caller may take.
class PurchaseRequestSheet extends StatefulWidget {
  const PurchaseRequestSheet({required this.request, super.key});

  final InvPurchaseRequest request;

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

  Future<void> _act(String fn, Map<String, Object?> extra, String done) =>
      procSubmit(
        context,
        (p) => p.act(fn, {'id': widget.request.id, ...extra}),
        done: done,
      );

  Future<void> _decide(String decision, String done) => _act('inv-pr-decide', {
    'decision': decision,
    'comment': _comment.text.trim(),
  }, done);

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final p = context.read<ProcurementProvider>();
    final a = context.read<InventoryProvider>().access;
    final mine = r.createdBy == p.uid;
    final decides = r.isPending && a.can('inv.pr.approve');
    final cancel = mine && r.isCancellable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.number, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${statusLabel(r.status)} · ${statusLabel(r.priority)} priority · '
          'needed by ${r.requiredDate}',
        ),
        Text(r.purpose),
        if (r.remarks != null && r.remarks!.isNotEmpty) Text(r.remarks!),
        const SizedBox(height: 8),
        for (final l in r.lines)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(p.itemName(l.itemId)),
            trailing: Text(
              '${fmtQty(l.qty)} × ${fmtQty(l.estPrice)}'
              '${l.qtyOrdered > 0 ? ' · ordered ${fmtQty(l.qtyOrdered)}' : ''}',
            ),
          ),
        Text('Estimated total: ${fmtQty(r.total)}'),
        if (r.history.isNotEmpty) ...[
          const Divider(),
          for (final h in r.history)
            Text(
              '${h.at?.toString().substring(0, 16) ?? ''} · '
              '${statusLabel(h.action)}'
              '${h.comment == null ? '' : ': ${h.comment}'}',
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
            if (mine && r.isEditable) ...[
              FilledButton(
                onPressed: () => _act('inv-pr-submit', {}, 'Submitted'),
                child: const Text('Submit for approval'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await context.push(
                    AppRoutes.inventoryPurchaseRequestForm,
                    extra: r,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Edit'),
              ),
            ],
            if (cancel)
              TextButton(
                onPressed: () => _act('inv-pr-cancel', {
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
