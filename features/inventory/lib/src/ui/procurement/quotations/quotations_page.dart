import 'dart:math';

import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/quotations/widgets/quotation_comparison.dart';
import 'package:inventory/src/ui/procurement/quotations/widgets/quotation_details.dart';
import 'package:provider/provider.dart';

/// Quotations of one request (FRS 10.15): side-by-side comparison, select the preferred one.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({required this.request, super.key});

  final InventoryPurchaseRequest request;

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  Future<void> _load() async {
    final procurementProvider = context.read<ProcurementProvider>();
    final access = context.read<InventoryProvider>().access;
    await procurementProvider.loadQuotations(widget.request.id);
    await procurementProvider.loadOrders(access);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _select(InventoryQuotation quotation) async {
    // The dialog owns the controller: disposing it here would break the closing animation.
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final reason = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Select ${quotation.number}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specify why this quotation is selected (e.g. lowest evaluated price, earliest delivery, vendor reliability).',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Selection reason *',
                    hintText: 'e.g. Lowest total cost and fastest delivery',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(dialogContext),
                variant: AppButtonVariant.ghost,
              ),
              AppButton(
                label: 'Select Quotation',
                onPressed: () {
                  if (reason.text.trim().isEmpty) {
                    return setDialogState(() => error = 'A reason is required');
                  }
                  Navigator.pop(dialogContext, reason.text.trim());
                },
              ),
            ],
          ),
        );
      },
    );
    if (text == null || !mounted) return;
    final procurementProvider = context.read<ProcurementProvider>();
    final result = await procurementProvider.act('inventory-quotation-select', {
      'id': quotation.id,
      'reason': text,
    });
    if (!mounted) return;
    if (result == null) {
      showMessage(
        context,
        procurementProvider.errorMessage ?? 'Could not select quotation',
      );
    } else {
      await _load();
    }
  }

  /// Records a draft as final so it can be selected.
  Future<void> _finalize(InventoryQuotation quotation) async {
    final procurementProvider = context.read<ProcurementProvider>();
    final result = await procurementProvider.act('inventory-quotation-save', {
      'id': quotation.id,
      'purchaseRequestId': quotation.purchaseRequestId,
      'vendorId': quotation.vendorId,
      'vendorRef': quotation.vendorRef ?? '',
      'validUntil': quotation.validUntil,
      'deliveryDays': quotation.deliveryDays,
      'lineItems': [
        for (final line in quotation.lineItems)
          {
            'itemId': line.itemId,
            'variantId': ?line.variantId,
            'quantity': line.quantity,
            'unitPrice': line.unitPrice,
          },
      ],
      'discount': quotation.discount,
      'tax': quotation.tax,
      'delivery': quotation.delivery,
      'remarks': quotation.remarks ?? '',
      'final': true,
    });
    if (!mounted) return;
    if (result == null) {
      showMessage(
        context,
        procurementProvider.errorMessage ?? 'Could not record quotation',
      );
    } else {
      showMessage(context, 'Quotation recorded');
      await _load();
    }
  }

  /// The live (not cancelled) purchase order raised from [quotation], if any.
  InventoryPurchaseOrder? _orderOf(
    ProcurementProvider provider,
    InventoryQuotation quotation,
  ) => provider.orders
      .where(
        (order) =>
            order.quotationId == quotation.id && order.status != 'cancelled',
      )
      .firstOrNull;

  Future<void> _open(String route, Object extra) async {
    await context.push(route, extra: extra);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final quotations = procurementProvider.quotations;
    final purchaseRequest = widget.request;
    final items = [
      for (final purchaseRequestLine in purchaseRequest.lineItems)
        purchaseRequestLine.itemId,
    ];

    final lowestTotal = quotations.isNotEmpty
        ? quotations.map((quotation) => quotation.total).reduce(min)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quotations · ${purchaseRequest.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(InventoryRoutes.inventoryQuotationForm, (
          purchaseRequest,
          null,
        )),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Quotation'),
      ),
      body: CenteredBody(
        child: quotations.isEmpty
            ? Center(
                child: procurementProvider.isLoading
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.request_quote_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No quotations received yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Record quotes from multiple vendors to compare prices and delivery schedules before issuing a purchase order.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  // Comparison Header Card
                  QuotationComparison(
                    quotations: quotations,
                    itemIds: items,
                    vendorName: procurementProvider.vendorName,
                    itemName: procurementProvider.itemName,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Quotation Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quotation Cards
                  for (final quotation in quotations) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: quotation.selected
                              ? Colors.green
                              : theme.colorScheme.outlineVariant,
                          width: quotation.selected ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        procurementProvider.vendorName(
                                          quotation.vendorId,
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        '${quotation.number}${quotation.vendorRef == null ? '' : ' · Ref: ${quotation.vendorRef}'}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (quotation.selected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'SELECTED',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (quotation.total == lowestTotal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Lowest Quote',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Total: ${quotation.total.toRupees()}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Valid until: ${quotation.validUntil}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (quotation.selectionReason != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Reason: ${quotation.selectionReason}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.green[900],
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            QuotationDetails(
                              quotation: quotation,
                              itemName: procurementProvider.itemName,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (quotation.isDraft) ...[
                                  AppButton(
                                    label: 'Edit Draft',
                                    onPressed: () => _open(
                                      InventoryRoutes.inventoryQuotationForm,
                                      (purchaseRequest, quotation),
                                    ),
                                    variant: AppButtonVariant.outline,
                                    leadingIcon: Icons.edit_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton(
                                    label: 'Record Quotation',
                                    onPressed: () => _finalize(quotation),
                                    leadingIcon: Icons.check_circle_outline,
                                  ),
                                ] else if (!quotation.selected)
                                  AppButton(
                                    label: 'Select this Quote',
                                    onPressed: () => _select(quotation),
                                    leadingIcon: Icons.check_circle_outline,
                                  )
                                else if (_orderOf(
                                      procurementProvider,
                                      quotation,
                                    )
                                    case final order?)
                                  AppButton(
                                    label: 'View ${order.number}',
                                    onPressed: () => _open(
                                      InventoryRoutes
                                          .inventoryPurchaseOrderDetail,
                                      order,
                                    ),
                                    variant: AppButtonVariant.outline,
                                    leadingIcon: Icons.receipt_long_outlined,
                                  )
                                else
                                  AppButton(
                                    label: 'Create PO from Quote',
                                    onPressed: () => _open(
                                      InventoryRoutes
                                          .inventoryPurchaseOrderForm,
                                      (purchaseRequest, quotation, null),
                                    ),
                                    leadingIcon:
                                        Icons.shopping_cart_checkout_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}
