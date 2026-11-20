import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';

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
    final today = todayIST();
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
                    'Dated ${invoice.invoiceDate.toDisplayDay()}',
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
                      'Due: ${invoice.dueDate.toDisplayDay()}',
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
                          invoice.total.toRupees(),
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
                          invoice.paidAmount.toRupees(),
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
                          invoice.outstanding.toRupees(),
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
    final color = inventoryStatusColor(status);
    return _StatusConfig(
      label: inventoryStatusLabel(status),
      foreground: color,
      background: color.withValues(alpha: 0.15),
    );
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
