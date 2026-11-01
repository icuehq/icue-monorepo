import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/proc_ui.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One invoice: amounts, and the payment status Finance reports (set here as a record only).
class InvoiceSheet extends StatelessWidget {
  const InvoiceSheet({required this.invoice, super.key});

  final InvInvoice invoice;

  Future<void> _ask(
    BuildContext context, {
    required String title,
    required String label,
    required Future<void> Function(String value) then,
    bool number = false,
    String? initial,
  }) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = c.text.trim();
    c.dispose();
    if (ok == true && context.mounted) await then(value);
  }

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final p = context.read<ProcurementProvider>();
    final op = context.read<InventoryProvider>().access.can(
      'inv.procure.operate',
    );
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(i.invoiceNo, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${statusLabel(i.statusOn(today))} · ${p.vendorName(i.vendorId)} · '
          '${i.poNumber}',
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
        if (op && !i.isCancelled)
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
                  then: (v) => procSubmit(
                    context,
                    (p) => p.act('inv-invoice-setPayment', {
                      'id': i.id,
                      'paidAmount': double.tryParse(v) ?? -1,
                    }),
                    done: 'Payment status updated',
                  ),
                ),
                child: const Text('Update payment'),
              ),
              if (i.isUnpaid)
                TextButton(
                  onPressed: () => _ask(
                    context,
                    title: 'Cancel ${i.invoiceNo}',
                    label: 'Reason *',
                    then: (v) => procSubmit(
                      context,
                      (p) => p.act('inv-invoice-cancel', {
                        'id': i.id,
                        'reason': v,
                      }),
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
