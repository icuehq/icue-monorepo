import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/invoices/widgets/invoice_card.dart';
import 'package:inventory/src/ui/procurement/invoices/widgets/invoice_sheet.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:provider/provider.dart';

/// Vendor invoices (FRS 10.18). Payment status mirrors what Finance reports.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  static const _statuses = {
    'unpaid': 'Unpaid',
    'partially_paid': 'Partially paid',
    'paid': 'Paid',
    'overdue': 'Overdue',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (!mounted) return;
    final provider = context.read<ProcurementProvider>();
    await provider.ensureVendors();
    await provider.invoiceList.load();
  }

  Future<void> _open(InventoryInvoice invoice) async {
    await showFormPage(context, () => InvoiceSheet(invoice: invoice));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProcurementProvider>();
    return PagedListPage<InventoryInvoice>(
      title: 'Vendor Invoices',
      state: provider.invoiceList,
      statuses: _statuses,
      searchHint: 'Search by invoice number (as written)…',
      emptyIcon: Icons.receipt_outlined,
      emptyMessage: 'Record vendor invoices directly against purchase orders once received.',
      onRefresh: _load,
      itemCard: (context, invoice) => InvoiceCard(
        invoice: invoice,
        vendorName: provider.vendorName(invoice.vendorId),
        onTap: () => _open(invoice),
      ),
      table: PagedListTable<InventoryInvoice>(
        title: 'Vendor invoices',
        state: provider.invoiceList,
        statuses: _statuses,
        searchHint: 'Invoice number (as written)',
        rowKey: (invoice) => invoice.id,
        rowLabel: (invoice) => invoice.invoiceNumber,
        onOpen: _open,
        emptyMessage: 'Record vendor invoices directly against purchase orders once received.',
        columns: [
          IcueTableColumn(
            id: 'invoice',
            label: 'Invoice',
            cellBuilder: (context, invoice) =>
                IcueTableCellText(invoice.invoiceNumber),
          ),
          IcueTableColumn(
            id: 'vendor',
            label: 'Vendor',
            flex: 2,
            cellBuilder: (context, invoice) =>
                IcueTableCellText(provider.vendorName(invoice.vendorId)),
          ),
          IcueTableColumn(
            id: 'order',
            label: 'Order',
            hideBelowWidth: 900,
            cellBuilder: (context, invoice) =>
                IcueTableCellText(invoice.purchaseOrderNumber),
          ),
          IcueTableColumn(
            id: 'dated',
            label: 'Dated',
            hideBelowWidth: 900,
            cellBuilder: (context, invoice) =>
                IcueTableCellText(invoice.invoiceDate.toDisplayDay()),
          ),
          IcueTableColumn(
            id: 'total',
            label: 'Total',
            cellBuilder: (context, invoice) =>
                IcueTableCellText(invoice.total.toRupees()),
          ),
          IcueTableColumn(
            id: 'outstanding',
            label: 'Outstanding',
            cellBuilder: (context, invoice) =>
                IcueTableCellText(invoice.outstanding.toRupees()),
          ),
          IcueTableColumn(
            id: 'payment',
            label: 'Payment',
            cellBuilder: (context, invoice) =>
                IcueTableCellText(humanizeStatus(invoice.statusOn(todayIST()))),
          ),
        ],
      ),
    );
  }
}
