import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';

Color issueStatusColor(String status) => switch (status) {
  'approved' => Colors.blue.shade700,
  'partially_issued' => Colors.purple.shade700,
  'issued' => Colors.green.shade700,
  'rejected' => Colors.red.shade700,
  _ => Colors.orange.shade800,
};

String formatIssueDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class IssueStatusPill extends StatelessWidget {
  const IssueStatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = issueStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        humanizeStatus(status),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Section container shared by the request screen's blocks.
class IssueSection extends StatelessWidget {
  const IssueSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Request → Approval → Issued progress, so the next step is obvious.
class IssueProgress extends StatelessWidget {
  const IssueProgress(this.request, {super.key});

  final InventoryIssueRequest request;

  @override
  Widget build(BuildContext context) {
    final rejected = request.status == 'rejected';
    final decided = !request.isPending;
    final issuing = request.status == 'partially_issued';
    final issued = request.status == 'issued';
    final steps = [
      ('Requested', true, false),
      (rejected ? 'Rejected' : 'Approved', decided, rejected),
      (issuing ? 'Partly issued' : 'Issued', issued || issuing, false),
    ];
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final (index, (label, done, failed)) in steps.indexed) ...[
          if (index > 0)
            Expanded(
              child: Divider(
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                thickness: 2,
              ),
            ),
          Column(
            children: [
              Icon(
                failed
                    ? Icons.cancel_rounded
                    : done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: failed
                    ? theme.colorScheme.error
                    : done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ],
    );
  }
}

class IssueSummary extends StatelessWidget {
  const IssueSummary({
    required this.request,
    required this.storeName,
    super.key,
  });

  final InventoryIssueRequest request;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final requesterId = int.tryParse(request.createdBy);
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );

    return IssueSection(
      title: request.number,
      trailing: IssueStatusPill(request.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.purpose,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          row(Icons.storefront_outlined, storeName),
          if (request.destination?.isNotEmpty ?? false)
            row(Icons.place_outlined, 'Destination: ${request.destination}'),
          row(
            Icons.person_outline_rounded,
            'Requested by '
            '${requesterId == null ? request.createdBy : staffDisplayName(requesterId)}'
            '${request.createdAt == null ? '' : ' on ${formatIssueDate(request.createdAt!)}'}',
          ),
          const SizedBox(height: 14),
          IssueProgress(request),
          if (request.approvalComment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${request.status == 'rejected' ? 'Reason' : 'Approver note'}: '
                '${request.approvalComment}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Requested items with their approved / issued progress; the approver edits quantities in place.
class IssueItems extends StatelessWidget {
  const IssueItems({
    required this.request,
    required this.itemName,
    this.approvedControllers,
    super.key,
  });

  final InventoryIssueRequest request;
  final String Function(String itemId) itemName;

  /// One controller per line while the approver is deciding, else null.
  final List<TextEditingController>? approvedControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = approvedControllers;
    return IssueSection(
      title: 'Items (${request.lineItems.length})',
      child: Column(
        children: [
          for (final (index, line) in request.lineItems.indexed) ...[
            if (index > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    itemName(line.itemId),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Requested ${formatQuantity(line.requested)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (editing != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  controller: editing[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalInputFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Approve quantity',
                    isDense: true,
                  ),
                ),
              )
            else if (line.approved != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: line.approved == 0
                    ? 0
                    : (line.issued / line.approved!).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                'Approved ${formatQuantity(line.approved!)} · '
                'Issued ${formatQuantity(line.issued)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
