import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/transfer_widgets.dart';
import 'package:school_library/school_library.dart';

class TransferCard extends StatelessWidget {
  const TransferCard({
    required this.transfer,
    required this.fromName,
    required this.toName,
    required this.nextAction,
    required this.onTap,
    super.key,
  });

  final LibraryTransfer transfer;
  final String fromName;
  final String toName;
  final String? nextAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final copies = transfer.lineItems.length;
    final received = copies - transfer.pending.length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: nextAction == null
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
              : theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transfer.number,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  TransferStatusPill(transfer.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fromName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: muted,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      toName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  '$copies ${copies == 1 ? 'copy' : 'copies'}',
                  if (transfer.status == 'partially_received')
                    '$received received',
                  if (transfer.requestedDate != null)
                    'Requested ${transfer.requestedDate}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (nextAction != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      nextAction!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
