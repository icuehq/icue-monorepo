import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Vendor invoices recorded against a purchase order, with their payment status.
class PurchaseOrderInvoicesSection extends StatefulWidget {
  const PurchaseOrderInvoicesSection({required this.orderId, super.key});

  final String orderId;

  @override
  State<PurchaseOrderInvoicesSection> createState() =>
      _PurchaseOrderInvoicesSectionState();
}

class _PurchaseOrderInvoicesSectionState
    extends State<PurchaseOrderInvoicesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadInvoices(
        context.read<InventoryProvider>().access,
        purchaseOrderId: widget.orderId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = context
        .watch<ProcurementProvider>()
        .invoices
        .where((invoice) => invoice.purchaseOrderId == widget.orderId)
        .toList();
    if (invoices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Invoices', style: Theme.of(context).textTheme.titleSmall),
        for (final invoice in invoices)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${invoice.invoiceNumber} · ${invoice.invoiceDate.toDisplayDay()}',
            ),
            subtitle: Text(
              invoice.paymentStatus == 'unpaid'
                  ? invoice.total.toRupees()
                  : '${invoice.total.toRupees()} · '
                        '${invoice.outstanding.toRupees()} outstanding',
            ),
            trailing: Text(invoice.paymentStatus.replaceAll('_', ' ')),
          ),
      ],
    );
  }
}
