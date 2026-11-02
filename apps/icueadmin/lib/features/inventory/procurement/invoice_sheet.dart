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
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: number ? 'e.g. 1500.00' : 'Reason for cancellation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
    final theme = Theme.of(context);
    final i = invoice;
    final procurementProvider = context.read<ProcurementProvider>();
    final canOperate = context.read<InventoryProvider>().access.can(
      'inventory.procure.operate',
    );
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final status = i.statusOn(today);
    final isOverdue = status == 'overdue';
    final vendor = procurementProvider.vendorName(i.vendorId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Invoice No, Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.invoiceNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$vendor · PO: ${i.purchaseOrderNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(humanizeStatus(status)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date & PO Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Invoice Date: ${i.invoiceDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (i.dueDate != null) ...[
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.event_available_outlined,
                    size: 16,
                    color: isOverdue ? theme.colorScheme.error : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${i.dueDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOverdue ? theme.colorScheme.error : null,
                      fontWeight: isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Breakdown Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: theme.textTheme.bodySmall),
                      Text(
                        '₹${money(i.subtotal)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (i.discount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount', style: theme.textTheme.bodySmall),
                        Text(
                          '-₹${money(i.discount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  if (i.tax > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tax', style: theme.textTheme.bodySmall),
                        Text(
                          '+₹${money(i.tax)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Invoiced',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${money(i.total)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paid Amount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green[800],
                        ),
                      ),
                      Text(
                        '₹${money(i.paidAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Outstanding Due',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: i.outstanding > 0
                              ? (isOverdue
                                    ? theme.colorScheme.error
                                    : Colors.orange[900])
                              : Colors.green[800],
                        ),
                      ),
                      Text(
                        '₹${money(i.outstanding)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: i.outstanding > 0
                              ? (isOverdue
                                    ? theme.colorScheme.error
                                    : Colors.orange[900])
                              : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (i.paymentRef != null && i.paymentRef!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Finance Reference: ${i.paymentRef}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Actions
          if (canOperate && !i.isCancelled) ...[
            FilledButton.icon(
              onPressed: () => _ask(
                context,
                title: 'Update Paid Amount',
                label: 'Total paid amount so far (₹)',
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
              icon: const Icon(Icons.payment_rounded),
              label: const Text('Update Payment Status'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (i.isUnpaid) ...[
              const SizedBox(height: 8),
              Align(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => _ask(
                    context,
                    title: 'Cancel ${i.invoiceNumber}',
                    label: 'Cancellation reason *',
                    then: (value) => procSubmit(
                      context,
                      (procurementProvider) => procurementProvider.act(
                        'inventory-invoice-cancel',
                        {'id': i.id, 'reason': value},
                      ),
                      done: 'Invoice cancelled',
                    ),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Invoice'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
