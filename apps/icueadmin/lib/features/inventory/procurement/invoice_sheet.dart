import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One invoice: amounts, and the payment status Finance reports (set here as a record only).
class InvoiceSheet extends StatelessWidget {
  const InvoiceSheet({required this.invoice, super.key});

  final InventoryInvoice invoice;

  Future<void> _ask(
    BuildContext context, {
    required String title,
    required String label,
    required Future<void> Function(String value) then,
    bool number = false,
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = controller.text.trim();
    controller.dispose();
    if (ok == true && context.mounted) await then(value);
  }

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final currentProcurementProvider = context.read<ProcurementProvider>();
    final currentValue = context.read<InventoryProvider>().access.can(
      'inventory.procure.operate',
    );
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(i.invoiceNumber, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${humanizeStatus(i.statusOn(today))} · ${currentProcurementProvider.vendorName(i.vendorId)} · '
          '${i.purchaseOrderNumber}',
        ),
        Text(
          'Dated ${i.invoiceDate}${i.dueDate == null ? '' : ' · due ${i.dueDate}'}',
        ),
        const SizedBox(height: 8),
        Text(
          'Subtotal ${money(i.subtotal)} · discount ${money(i.discount)} · '
          'tax ${money(i.tax)}',
        ),
        Text(
          'Total ${money(i.total)} · paid ${money(i.paidAmount)} · '
          'outstanding ${money(i.outstanding)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (i.paymentRef != null) Text('Finance reference: ${i.paymentRef}'),
        const SizedBox(height: 12),
        if (currentValue && !i.isCancelled)
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _ask(
                  context,
                  title: 'Paid so far',
                  label: 'Total paid amount',
                  number: true,
                  initial: i.paidAmount.toStringAsFixed(2),
                  then: (value) => procSubmit(
                    context,
                    (procurementProvider) => procurementProvider.act(
                      'inventory-invoice-setPayment',
                      {'id': i.id, 'paidAmount': double.tryParse(value) ?? -1},
                    ),
                    done: 'Payment status updated',
                  ),
                ),
                child: const Text('Update payment'),
              ),
              if (i.isUnpaid)
                TextButton(
                  onPressed: () => _ask(
                    context,
                    title: 'Cancel ${i.invoiceNumber}',
                    label: 'Reason *',
                    then: (value) => procSubmit(
                      context,
                      (procurementProvider) => procurementProvider.act(
                        'inventory-invoice-cancel',
                        {'id': i.id, 'reason': value},
                      ),
                      done: 'Cancelled',
                    ),
                  ),
                  child: const Text('Cancel invoice'),
                ),
            ],
          ),
      ],
    );
  }
}
