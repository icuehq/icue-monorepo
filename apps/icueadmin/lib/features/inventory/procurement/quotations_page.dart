import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
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
      builder: (context) => AlertDialog(
        title: Text('Select ${quotation.number}'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Select'),
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
        procurementProvider.errorMessage ?? 'Could not select',
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
    final procurementProvider = context.watch<ProcurementProvider>();
    final quotations = procurementProvider.quotations;
    final purchaseRequest = widget.request;
    final items = [
      for (final purchaseRequestLine in purchaseRequest.lineItems)
        purchaseRequestLine.itemId,
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Quotations · ${purchaseRequest.number}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _open(AppRoutes.inventoryQuotationForm, (purchaseRequest, null)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quotation'),
      ),
      body: quotations.isEmpty
          ? Center(
              child: procurementProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      procurementProvider.errorMessage ?? 'No quotations yet',
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Unit price')),
                      for (final quotation in quotations)
                        DataColumn(
                          label: Text(
                            procurementProvider.vendorName(quotation.vendorId),
                          ),
                        ),
                    ],
                    rows: [
                      for (final id in items)
                        DataRow(
                          cells: [
                            DataCell(Text(procurementProvider.itemName(id))),
                            for (final quotation in quotations)
                              DataCell(
                                Text(
                                  quotation.lineItems
                                      .where(
                                        (orderLine) => orderLine.itemId == id,
                                      )
                                      .map(
                                        (orderLine) =>
                                            money(orderLine.unitPrice),
                                      )
                                      .join(),
                                ),
                              ),
                          ],
                        ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Final price')),
                          for (final quotation in quotations)
                            DataCell(Text(money(quotation.total))),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Delivery (days)')),
                          for (final quotation in quotations)
                            DataCell(Text('${quotation.deliveryDays ?? '-'}')),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Valid until')),
                          for (final quotation in quotations)
                            DataCell(Text(quotation.validUntil)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final quotation in quotations)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${quotation.number} · ${procurementProvider.vendorName(quotation.vendorId)}'
                        '${quotation.selected ? ' · SELECTED' : ''}',
                      ),
                      subtitle: Text(
                        '${humanizeStatus(quotation.status)} · total ${money(quotation.total)}'
                        '${quotation.selectionReason == null ? '' : '\n${quotation.selectionReason}'}',
                      ),
                      trailing: Wrap(
                        children: [
                          if (quotation.isDraft)
                            IconButton(
                              tooltip: 'Edit draft',
                              icon: const Icon(Icons.edit_rounded),
                              onPressed: () => _open(
                                AppRoutes.inventoryQuotationForm,
                                (purchaseRequest, quotation),
                              ),
                            )
                          else if (!quotation.selected)
                            TextButton(
                              onPressed: () => _select(quotation),
                              child: const Text('Select'),
                            )
                          else
                            TextButton(
                              onPressed: () => _open(
                                AppRoutes.inventoryPurchaseOrderForm,
                                (purchaseRequest, quotation, null),
                              ),
                              child: const Text('Create PO'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
