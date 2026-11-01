import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/invoice_sheet.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Vendor invoice records (FRS 10.18). Recorded from a purchase order; this lists and updates their payment status.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  // `overdue` is derived from the due date, so it filters client-side.
  static const _statuses = [
    'unpaid',
    'partially_paid',
    'paid',
    'overdue',
    'cancelled',
  ];
  String? _status;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.categories.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<ProcurementProvider>().loadInvoices(
        inv.access,
        status: _status == 'overdue' ? null : _status,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProcurementProvider>();
    final shown = [
      for (final i in p.invoices)
        if (_status != 'overdue' || i.statusOn(_today) == 'overdue') i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor invoices')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _status,
              items: [
                const DropdownMenuItem(child: Text('All statuses')),
                for (final s in _statuses)
                  DropdownMenuItem(value: s, child: Text(statusLabel(s))),
              ],
              onChanged: (v) {
                _status = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No invoices'),
                  )
                : ListView(
                    children: [
                      for (final i in shown)
                        ListTile(
                          title: Text(
                            '${i.invoiceNo} · ${p.vendorName(i.vendorId)}',
                          ),
                          subtitle: Text(
                            '${i.poNumber} · total ${money(i.total)} · '
                            'outstanding ${money(i.outstanding)}'
                            '${i.dueDate == null ? '' : ' · due ${i.dueDate}'}',
                          ),
                          trailing: Chip(
                            label: Text(statusLabel(i.statusOn(_today))),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showInvSheet(
                              context,
                              () => InvoiceSheet(invoice: i),
                            );
                            if (mounted) await _load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
