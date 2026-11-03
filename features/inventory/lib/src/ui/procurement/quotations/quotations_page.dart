import 'dart:math';

import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';
import 'package:provider/provider.dart';

/// Quotations of one request (FRS 10.15): side-by-side comparison, select the preferred one.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({required this.request, super.key});

  final InventoryPurchaseRequest request;

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  Future<void> _load() =>
      context.read<ProcurementProvider>().loadQuotations(widget.request.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _select(InventoryQuotation quotation) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              decoration: const InputDecoration(
                labelText: 'Selection reason *',
                hintText: 'e.g. Lowest total cost and fastest delivery',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Select Quotation'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;
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
      body: quotations.isEmpty
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
              padding: const EdgeInsets.all(16),
              children: [
                // Comparison Header Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Price Comparison Table',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            ),
                            columns: [
                              const DataColumn(
                                label: Text(
                                  'Item / Metric',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              for (final quotation in quotations)
                                DataColumn(
                                  label: Text(
                                    procurementProvider.vendorName(
                                      quotation.vendorId,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: quotation.selected
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (final id in items)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(procurementProvider.itemName(id)),
                                    ),
                                    for (final quotation in quotations)
                                      DataCell(
                                        Text(
                                          quotation.lineItems
                                              .where(
                                                (line) => line.itemId == id,
                                              )
                                              .map(
                                                (line) =>
                                                    '₹${money(line.unitPrice)}',
                                              )
                                              .join(),
                                        ),
                                      ),
                                  ],
                                ),
                              DataRow(
                                cells: [
                                  const DataCell(
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  for (final quotation in quotations)
                                    DataCell(
                                      Text(
                                        '₹${money(quotation.total)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: quotation.total == lowestTotal
                                              ? Colors.green[800]
                                              : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              DataRow(
                                cells: [
                                  const DataCell(Text('Delivery Lead Time')),
                                  for (final quotation in quotations)
                                    DataCell(
                                      Text(
                                        quotation.deliveryDays != null
                                            ? '${quotation.deliveryDays} days'
                                            : 'Not specified',
                                      ),
                                    ),
                                ],
                              ),
                              DataRow(
                                cells: [
                                  const DataCell(Text('Validity')),
                                  for (final quotation in quotations)
                                    DataCell(Text(quotation.validUntil)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: Colors.green.withValues(alpha: 0.15),
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
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
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
                                'Total: ₹${money(quotation.total)}',
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
                                          ?.copyWith(color: Colors.green[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (quotation.isDraft)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Edit Draft'),
                                  onPressed: () => _open(
                                    InventoryRoutes.inventoryQuotationForm,
                                    (purchaseRequest, quotation),
                                  ),
                                )
                              else if (!quotation.selected)
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Select this Quote'),
                                  onPressed: () => _select(quotation),
                                )
                              else
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.shopping_cart_checkout_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Create PO from Quote'),
                                  onPressed: () => _open(
                                    InventoryRoutes.inventoryPurchaseOrderForm,
                                    (purchaseRequest, quotation, null),
                                  ),
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
    );
  }
}
