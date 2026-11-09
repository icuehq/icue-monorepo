import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/invoices/widgets/invoice_dialog.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/purchase_order_pdf.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/widgets/purchase_order_invoices_section.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/widgets/purchase_order_receipts_section.dart';
import 'package:inventory/src/ui/procurement/purchase_orders/widgets/purchase_order_revision_dialog.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:provider/provider.dart';

/// One purchase order: lines with receiving progress, PDF, and the actions its status allows.
class PurchaseOrderPage extends StatelessWidget {
  const PurchaseOrderPage({required this.order, super.key});

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
    final reason = await askText(
      context,
      title: title,
      label: required ? 'Reason *' : 'Reason',
      hint: 'e.g. Discontinued item / Supplier cancellation',
      required: required,
    );
    if (reason != null && context.mounted) {
      await _act(context, value, {'reason': reason}, done);
    }
  }

  Future<void> _revise(BuildContext context) async {
    final data = await showPurchaseOrderRevisionDialog(context, order: order);
    if (data != null && context.mounted) {
      await _act(
        context,
        'inventory-purchaseOrder-revise',
        data,
        'Revision recorded',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchaseOrder = order;
    final procurementProvider = context.read<ProcurementProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final canOperate = inventoryProvider.access.can(
      'inventory.procure.operate',
    );
    final canStockOperate = inventoryProvider.access.can(
      'inventory.stock.operate',
    );
    final vendor = procurementProvider.vendorName(purchaseOrder.vendorId);

    return Scaffold(
      appBar: AppBar(title: Text(purchaseOrder.number)),
      body: CenteredBody(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: PO Number, Status, Revision
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              purchaseOrder.number,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (purchaseOrder.revision > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Revision ${purchaseOrder.revision}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$vendor · Deliver to Campus ${purchaseOrder.deliveryCampusId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(humanizeStatus(purchaseOrder.status)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Card
              Container(
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
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expected Delivery: ${purchaseOrder.expectedDate.toDisplayDay()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (purchaseOrder.ackRef != null)
                          Text(
                            'Ack: ${purchaseOrder.ackRef}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (purchaseOrder.terms != null &&
                        purchaseOrder.terms!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Terms: ${purchaseOrder.terms}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Line Items & Progress
              Text(
                'Order Items & Delivery Status',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final orderLine in purchaseOrder.lineItems)
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
                                procurementProvider.itemName(orderLine.itemId),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Accepted: ${orderLine.quantityAccepted.toQuantityText()} / ${orderLine.quantity.toQuantityText()}'
                                '${orderLine.quantityRejected > 0 ? ' · ${orderLine.quantityRejected.toQuantityText()} rejected' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      orderLine.quantityAccepted >=
                                          orderLine.quantity
                                      ? Colors.green[800]
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${orderLine.quantity.toQuantityText()} × ${orderLine.unitPrice.toRupees()}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Totals summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: theme.textTheme.bodySmall),
                        Text(
                          purchaseOrder.subtotal.toRupees(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (purchaseOrder.discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount', style: theme.textTheme.bodySmall),
                          Text(
                            '-${purchaseOrder.discount.toRupees()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    if (purchaseOrder.tax > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax', style: theme.textTheme.bodySmall),
                          Text(
                            '+${purchaseOrder.tax.toRupees()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    if (purchaseOrder.delivery > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery', style: theme.textTheme.bodySmall),
                          Text(
                            '+${purchaseOrder.delivery.toRupees()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          purchaseOrder.total.toRupees(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PurchaseOrderReceiptsSection(orderId: purchaseOrder.id),
              PurchaseOrderInvoicesSection(orderId: purchaseOrder.id),
              const SizedBox(height: 20),

              if (canStockOperate && purchaseOrder.canReceive) ...[
                AppButton(
                  label: 'Receive Goods (GRN)',
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(
                      InventoryRoutes.inventoryPoReceive,
                      extra: purchaseOrder,
                    );
                  },
                  leadingIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
              ],

              if (canOperate && purchaseOrder.isIssued) ...[
                AppButton(
                  label: 'Confirm Vendor Acknowledged',
                  onPressed: () => _act(
                    context,
                    'inventory-purchaseOrder-acknowledge',
                    {},
                    'Vendor acknowledged',
                  ),
                  leadingIcon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(height: 8),
              ],

              if (canOperate && purchaseOrder.isDraft) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Issue PO',
                        onPressed: () => _act(
                          context,
                          'inventory-purchaseOrder-issue',
                          {},
                          'Purchase order issued',
                        ),
                        leadingIcon: Icons.send_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final router = GoRouter.of(context);
                          final request = await procurementProvider.request(
                            purchaseOrder.purchaseRequestId,
                          );
                          if (request == null) return;
                          navigator.pop();
                          await router.push(
                            InventoryRoutes.inventoryPurchaseOrderForm,
                            extra: (request, null, purchaseOrder),
                          );
                        },
                        variant: AppButtonVariant.outline,
                        leadingIcon: Icons.edit_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: 'Download / Share PDF',
                    onPressed: () => sharePurchaseOrderPdf(
                      purchaseOrder,
                      vendor: vendor,
                      itemName: procurementProvider.itemName,
                    ),
                    variant: AppButtonVariant.outline,
                    leadingIcon: Icons.picture_as_pdf_rounded,
                  ),
                  if (canOperate &&
                      !purchaseOrder.isDraft &&
                      purchaseOrder.status != 'cancelled')
                    AppButton(
                      label: 'Record Invoice',
                      onPressed: () async {
                        await InvoiceDialog.show(context, purchaseOrder);
                        if (!context.mounted) return;
                        await procurementProvider.loadInvoices(
                          inventoryProvider.access,
                          purchaseOrderId: purchaseOrder.id,
                        );
                      },
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.receipt_long_outlined,
                    ),
                  if (canOperate && purchaseOrder.canRevise)
                    AppButton(
                      label: 'Revise PO',
                      onPressed: () => _revise(context),
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.replay_rounded,
                    ),
                  if (canOperate && purchaseOrder.canClose)
                    AppButton(
                      label: 'Close PO',
                      onPressed: () => _withReason(
                        context,
                        'Close ${purchaseOrder.number}',
                        'inventory-purchaseOrder-close',
                        'Closed',
                        required: purchaseOrder.status != 'fully_received',
                      ),
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.done_all_rounded,
                    ),
                  if (canOperate && purchaseOrder.canCancel)
                    AppButton(
                      label: 'Cancel PO',
                      onPressed: () => _withReason(
                        context,
                        'Cancel ${purchaseOrder.number}',
                        'inventory-purchaseOrder-cancel',
                        'Cancelled',
                      ),
                      variant: AppButtonVariant.destructive,
                      leadingIcon: Icons.cancel_outlined,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
