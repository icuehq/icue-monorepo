import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/invoice_form_sheet.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_pdf.dart';
import 'package:icueadmin/features/inventory/procurement/purchase_order_receipts_section.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One purchase order: lines with receiving progress, PDF, and the actions its status allows.
class PurchaseOrderSheet extends StatelessWidget {
  const PurchaseOrderSheet({required this.order, super.key});

  final InventoryPurchaseOrder order;

  Future<void> _act(
    BuildContext context,
    String value,
    Map<String, Object?> extra,
    String done,
  ) => procSubmit(
    context,
    (procurementProvider) =>
        procurementProvider.act(value, {'id': order.id, ...extra}),
    done: done,
  );

  /// Asks for a reason, then runs [value]; [required] blocks an empty answer.
  Future<void> _withReason(
    BuildContext context,
    String title,
    String value,
    String done, {
    bool required = true,
  }) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: required ? 'Reason *' : 'Reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (ok == true && context.mounted) {
      await _act(context, value, {'reason': reason}, done);
    }
  }

  Future<void> _revise(BuildContext context) async {
    final procurementProvider = context.read<ProcurementProvider>();
    final prices = [
      for (final orderLine in order.lineItems)
        TextEditingController(text: formatQuantity(orderLine.unitPrice)),
    ];
    final reason = TextEditingController();
    final expected = TextEditingController(text: order.expectedDate);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revise ${order.number}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason *'),
              ),
              dateField(context, expected, 'Expected delivery'),
              for (final (n, l) in order.lineItems.indexed)
                TextField(
                  controller: prices[n],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${procurementProvider.itemName(l.itemId)} unit price',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save revision'),
          ),
        ],
      ),
    );
    final data = <String, Object?>{
      'reason': reason.text.trim(),
      'expectedDate': expected.text,
      'prices': [
        for (final (n, l) in order.lineItems.indexed)
          {
            'itemId': l.itemId,
            'variantId': ?l.variantId,
            'unitPrice': double.tryParse(prices[n].text.trim()) ?? l.unitPrice,
          },
      ],
    };
    for (final controller in [...prices, reason, expected]) {
      controller.dispose();
    }
    if (ok == true && context.mounted) {
      await _act(context, 'inventory-purchaseOrder-revise', data, 'Revised');
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseOrder = order;
    final procurementProvider = context.read<ProcurementProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final value = inventoryProvider.access.can('inventory.procure.operate');
    final vendor = procurementProvider.vendorName(purchaseOrder.vendorId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          purchaseOrder.number,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${humanizeStatus(purchaseOrder.status)} · $vendor · deliver to campus '
          '${purchaseOrder.deliveryCampusId} by ${purchaseOrder.expectedDate}',
        ),
        if (purchaseOrder.revision > 0)
          Text('Revision ${purchaseOrder.revision}'),
        if (purchaseOrder.ackRef != null)
          Text('Vendor ref: ${purchaseOrder.ackRef}'),
        const SizedBox(height: 8),
        for (final orderLine in purchaseOrder.lineItems)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(procurementProvider.itemName(orderLine.itemId)),
            subtitle: Text(
              'Accepted ${formatQuantity(orderLine.quantityAccepted)}'
              '${orderLine.quantityRejected > 0 ? ' · rejected ${formatQuantity(orderLine.quantityRejected)}' : ''}'
              ' of ${formatQuantity(orderLine.quantity)}',
            ),
            trailing: Text(
              '${formatQuantity(orderLine.quantity)} × ${money(orderLine.unitPrice)}',
            ),
          ),
        Text(
          'Subtotal ${money(purchaseOrder.subtotal)} · discount ${money(purchaseOrder.discount)} · '
          'tax ${money(purchaseOrder.tax)} · delivery ${money(purchaseOrder.delivery)}',
        ),
        Text(
          'Total ${money(purchaseOrder.total)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (purchaseOrder.terms != null && purchaseOrder.terms!.isNotEmpty)
          Text(purchaseOrder.terms!),
        PurchaseOrderReceiptsSection(orderId: purchaseOrder.id),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
              onPressed: () => sharePurchaseOrderPdf(
                purchaseOrder,
                vendor: vendor,
                itemName: procurementProvider.itemName,
              ),
            ),
            if (inventoryProvider.access.can('inventory.stock.operate') &&
                purchaseOrder.canReceive)
              FilledButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(
                    AppRoutes.inventoryPoReceive,
                    extra: purchaseOrder,
                  );
                },
                child: const Text('Receive goods'),
              ),
            if (value &&
                !purchaseOrder.isDraft &&
                purchaseOrder.status != 'cancelled')
              OutlinedButton(
                onPressed: () => InvoiceFormSheet.show(context, purchaseOrder),
                child: const Text('Record invoice'),
              ),
            if (value && purchaseOrder.isDraft) ...[
              FilledButton(
                onPressed: () => _act(
                  context,
                  'inventory-purchaseOrder-issue',
                  {},
                  'Issued',
                ),
                child: const Text('Issue'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final router = GoRouter.of(context);
                  final request = await procurementProvider.request(
                    purchaseOrder.purchaseRequestId,
                  );
                  if (request == null) return;
                  navigator.pop();
                  await router.push(
                    AppRoutes.inventoryPurchaseOrderForm,
                    extra: (request, null, purchaseOrder),
                  );
                },
                child: const Text('Edit'),
              ),
            ],
            if (value && purchaseOrder.isIssued)
              FilledButton(
                onPressed: () => _act(
                  context,
                  'inventory-purchaseOrder-acknowledge',
                  {},
                  'Acknowledged',
                ),
                child: const Text('Vendor acknowledged'),
              ),
            if (value && purchaseOrder.canRevise)
              OutlinedButton(
                onPressed: () => _revise(context),
                child: const Text('Revise'),
              ),
            if (value && purchaseOrder.canClose)
              OutlinedButton(
                onPressed: () => _withReason(
                  context,
                  'Close ${purchaseOrder.number}',
                  'inventory-purchaseOrder-close',
                  'Closed',
                  required: purchaseOrder.status != 'fully_received',
                ),
                child: const Text('Close'),
              ),
            if (value && purchaseOrder.canCancel)
              TextButton(
                onPressed: () => _withReason(
                  context,
                  'Cancel ${purchaseOrder.number}',
                  'inventory-purchaseOrder-cancel',
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
