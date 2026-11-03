import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    required this.invoice,
    required this.vendorName,
    this.onTap,
    super.key,
  });

  final InventoryInvoice invoice;
  final String vendorName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final status = invoice.statusOn(today);
    final isOverdue = status == 'overdue';
    final statusConfig = _getStatusConfig(status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Invoice Number, Vendor Name, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$vendorName · ${invoice.purchaseOrderNumber}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusConfig.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusConfig.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dates: Invoice date & Due date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Dated ${invoice.invoiceDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (invoice.dueDate != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.event_available_outlined,
                      size: 14,
                      color: isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${invoice.dueDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Financial Metrics
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Bill',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '₹${money(invoice.total)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid Amount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '₹${money(invoice.paidAmount)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Outstanding',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '₹${money(invoice.outstanding)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: invoice.outstanding > 0
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
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'paid':
        return _StatusConfig(
          label: 'Paid',
          foreground: Colors.green[800]!,
          background: Colors.green.withValues(alpha: 0.15),
        );
      case 'partially_paid':
        return _StatusConfig(
          label: 'Partially Paid',
          foreground: Colors.blue[800]!,
          background: Colors.blue.withValues(alpha: 0.15),
        );
      case 'unpaid':
        return _StatusConfig(
          label: 'Unpaid',
          foreground: Colors.amber[900]!,
          background: Colors.amber.withValues(alpha: 0.15),
        );
      case 'overdue':
        return _StatusConfig(
          label: 'OVERDUE',
          foreground: Colors.red[800]!,
          background: Colors.red.withValues(alpha: 0.15),
        );
      case 'cancelled':
        return _StatusConfig(
          label: 'Cancelled',
          foreground: Colors.grey[700]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
      default:
        return _StatusConfig(
          label: humanizeStatus(status),
          foreground: Colors.grey[800]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
