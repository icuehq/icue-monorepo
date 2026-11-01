import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/invoice_sheet.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) {
      await context.read<ProcurementProvider>().loadInvoices(
        inventoryProvider.access,
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
    final procurementProvider = context.watch<ProcurementProvider>();
    final shown = [
      for (final i in procurementProvider.invoices)
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
                for (final status in _statuses)
                  DropdownMenuItem(
                    value: status,
                    child: Text(humanizeStatus(status)),
                  ),
              ],
              onChanged: (value) {
                _status = value;
                _load();
              },
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: procurementProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            procurementProvider.errorMessage ?? 'No invoices',
                          ),
                  )
                : ListView(
                    children: [
                      for (final i in shown)
                        ListTile(
                          title: Text(
                            '${i.invoiceNumber} · ${procurementProvider.vendorName(i.vendorId)}',
                          ),
                          subtitle: Text(
                            '${i.purchaseOrderNumber} · total ${money(i.total)} · '
                            'outstanding ${money(i.outstanding)}'
                            '${i.dueDate == null ? '' : ' · due ${i.dueDate}'}',
                          ),
                          trailing: Chip(
                            label: Text(humanizeStatus(i.statusOn(_today))),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () async {
                            await showFormSheet(
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
