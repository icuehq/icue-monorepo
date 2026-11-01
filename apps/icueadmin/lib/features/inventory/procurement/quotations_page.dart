import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Quotations of one request (FRS 10.15): side-by-side comparison, select the preferred one.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({required this.request, super.key});

  final InvPurchaseRequest request;

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

  Future<void> _select(InvQuotation q) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select ${q.number}'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;
    final p = context.read<ProcurementProvider>();
    final res = await p.act('inv-quotation-select', {
      'id': q.id,
      'reason': text,
    });
    if (!mounted) return;
    if (res == null) {
      invSnack(context, p.errorMessage ?? 'Could not select');
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
    final p = context.watch<ProcurementProvider>();
    final qs = p.quotations;
    final r = widget.request;
    final items = [for (final l in r.lines) l.itemId];
    return Scaffold(
      appBar: AppBar(title: Text('Quotations · ${r.number}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(AppRoutes.inventoryQuotationForm, (r, null)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quotation'),
      ),
      body: qs.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'No quotations yet'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Unit price')),
                      for (final q in qs)
                        DataColumn(label: Text(p.vendorName(q.vendorId))),
                    ],
                    rows: [
                      for (final id in items)
                        DataRow(
                          cells: [
                            DataCell(Text(p.itemName(id))),
                            for (final q in qs)
                              DataCell(
                                Text(
                                  q.lines
                                      .where((l) => l.itemId == id)
                                      .map((l) => money(l.unitPrice))
                                      .join(),
                                ),
                              ),
                          ],
                        ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Final price')),
                          for (final q in qs) DataCell(Text(money(q.total))),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Delivery (days)')),
                          for (final q in qs)
                            DataCell(Text('${q.deliveryDays ?? '-'}')),
                        ],
                      ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Valid until')),
                          for (final q in qs) DataCell(Text(q.validUntil)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final q in qs)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${q.number} · ${p.vendorName(q.vendorId)}'
                        '${q.selected ? ' · SELECTED' : ''}',
                      ),
                      subtitle: Text(
                        '${statusLabel(q.status)} · total ${money(q.total)}'
                        '${q.selectionReason == null ? '' : '\n${q.selectionReason}'}',
                      ),
                      trailing: Wrap(
                        children: [
                          if (q.isDraft)
                            IconButton(
                              tooltip: 'Edit draft',
                              icon: const Icon(Icons.edit_rounded),
                              onPressed: () => _open(
                                AppRoutes.inventoryQuotationForm,
                                (r, q),
                              ),
                            )
                          else if (!q.selected)
                            TextButton(
                              onPressed: () => _select(q),
                              child: const Text('Select'),
                            )
                          else
                            TextButton(
                              onPressed: () => _open(
                                AppRoutes.inventoryPurchaseOrderForm,
                                (r, q, null),
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
