import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/po_pdf.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One purchase order: lines with receiving progress, PDF, and the actions its status allows.
class PurchaseOrderSheet extends StatelessWidget {
  const PurchaseOrderSheet({required this.order, super.key});

  final InvPurchaseOrder order;

  Future<void> _act(
    BuildContext context,
    String fn,
    Map<String, Object?> extra,
    String done,
  ) => procSubmit(
    context,
    (p) => p.act(fn, {'id': order.id, ...extra}),
    done: done,
  );

  /// Asks for a reason, then runs [fn]; [required] blocks an empty answer.
  Future<void> _withReason(
    BuildContext context,
    String title,
    String fn,
    String done, {
    bool required = true,
  }) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            labelText: required ? 'Reason *' : 'Reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final reason = c.text.trim();
    c.dispose();
    if (ok == true && context.mounted) {
      await _act(context, fn, {'reason': reason}, done);
    }
  }

  Future<void> _revise(BuildContext context) async {
    final p = context.read<ProcurementProvider>();
    final prices = [
      for (final l in order.lines)
        TextEditingController(text: fmtQty(l.unitPrice)),
    ];
    final reason = TextEditingController();
    final expected = TextEditingController(text: order.expectedDate);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revise ${order.number}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason *'),
              ),
              dateField(ctx, expected, 'Expected delivery'),
              for (final (n, l) in order.lines.indexed)
                TextField(
                  controller: prices[n],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${p.itemName(l.itemId)} unit price',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save revision'),
          ),
        ],
      ),
    );
    final data = <String, Object?>{
      'reason': reason.text.trim(),
      'expectedDate': expected.text,
      'prices': [
        for (final (n, l) in order.lines.indexed)
          {
            'itemId': l.itemId,
            'variantId': ?l.variantId,
            'unitPrice': double.tryParse(prices[n].text.trim()) ?? l.unitPrice,
          },
      ],
    };
    for (final c in [...prices, reason, expected]) {
      c.dispose();
    }
    if (ok == true && context.mounted) {
      await _act(context, 'inv-po-revise', data, 'Revised');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final p = context.read<ProcurementProvider>();
    final inv = context.read<InventoryProvider>();
    final op = inv.access.can('inv.procure.operate');
    final vendor = p.vendorName(o.vendorId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(o.number, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${statusLabel(o.status)} · $vendor · deliver to campus '
          '${o.deliveryCampusId} by ${o.expectedDate}',
        ),
        if (o.revision > 0) Text('Revision ${o.revision}'),
        if (o.ackRef != null) Text('Vendor ref: ${o.ackRef}'),
        const SizedBox(height: 8),
        for (final l in o.lines)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(p.itemName(l.itemId)),
            subtitle: Text(
              'Received ${fmtQty(l.qtyReceived)} of ${fmtQty(l.qty)}',
            ),
            trailing: Text('${fmtQty(l.qty)} × ${money(l.unitPrice)}'),
          ),
        Text(
          'Subtotal ${money(o.subtotal)} · discount ${money(o.discount)} · '
          'tax ${money(o.tax)} · delivery ${money(o.delivery)}',
        ),
        Text(
          'Total ${money(o.total)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (o.terms != null && o.terms!.isNotEmpty) Text(o.terms!),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
              onPressed: () =>
                  sharePoPdf(o, vendor: vendor, itemName: p.itemName),
            ),
            if (op && o.isDraft) ...[
              FilledButton(
                onPressed: () => _act(context, 'inv-po-issue', {}, 'Issued'),
                child: const Text('Issue'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final router = GoRouter.of(context);
                  final req = await p.request(o.prId);
                  if (req == null) return;
                  nav.pop();
                  await router.push(
                    AppRoutes.inventoryPurchaseOrderForm,
                    extra: (req, null, o),
                  );
                },
                child: const Text('Edit'),
              ),
            ],
            if (op && o.isIssued)
              FilledButton(
                onPressed: () =>
                    _act(context, 'inv-po-acknowledge', {}, 'Acknowledged'),
                child: const Text('Vendor acknowledged'),
              ),
            if (op && o.canRevise)
              OutlinedButton(
                onPressed: () => _revise(context),
                child: const Text('Revise'),
              ),
            if (op && o.canClose)
              OutlinedButton(
                onPressed: () => _withReason(
                  context,
                  'Close ${o.number}',
                  'inv-po-close',
                  'Closed',
                  required: o.status != 'fully_received',
                ),
                child: const Text('Close'),
              ),
            if (op && o.canCancel)
              TextButton(
                onPressed: () => _withReason(
                  context,
                  'Cancel ${o.number}',
                  'inv-po-cancel',
                  'Cancelled',
                ),
                child: const Text('Cancel PO'),
              ),
          ],
        ),
      ],
    );
  }
}
