import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Confirm receipt of an issue, or record a return with inspection split usable / damaged (FRS 10.9).
class IssueReturnSheet extends StatefulWidget {
  const IssueReturnSheet({required this.issue, super.key});

  final InventoryIssue issue;

  @override
  State<IssueReturnSheet> createState() => _IssueReturnSheetState();
}

class _IssueReturnSheetState extends State<IssueReturnSheet> {
  late final _usable = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  late final _damaged = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  final _returnedBy = TextEditingController();
  final _requestId = newRequestId();
  var _busy = false;

  @override
  void dispose() {
    _returnedBy.dispose();
    for (final controller in [..._usable, ..._damaged]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _return() async {
    final personErpId = int.tryParse(_returnedBy.text.trim());
    if (personErpId == null) {
      return showMessage(context, 'Enter the returning person\'s ERP ID');
    }
    final lineItems = [
      for (final (i, l) in widget.issue.lineItems.indexed)
        if (_v(_usable[i]) + _v(_damaged[i]) > 0)
          {
            'balanceId': l.balanceId,
            'quantityUsable': _v(_usable[i]),
            'quantityDamaged': _v(_damaged[i]),
          },
    ];
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter a returned quantity');
    }
    setState(() => _busy = true);
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-return-create', {
        'issueId': widget.issue.id,
        'returnedBy': {'type': 'staff', 'personErpId': personErpId},
        'lineItems': lineItems,
      }, requestId: _requestId),
      done: 'Return recorded successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStockProvider = context.read<StockProvider>();
    final issue = widget.issue;
    final outstandingLines = [
      for (final (i, line) in issue.lineItems.indexed)
        if (line.outstanding > 0) (index: i, line: line),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue #${issue.number}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (issue.createdAt != null)
                      Text(
                        'Issued on ${_formatDate(issue.createdAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: issue.acknowledged
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  issue.acknowledged ? 'Receipt Confirmed' : 'Unacknowledged',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: issue.acknowledged
                        ? Colors.green[800]
                        : Colors.orange[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!issue.acknowledged) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recipient has not yet acknowledged receiving these items.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => stockSubmit(
                      context,
                      (stockProvider) => stockProvider.act(
                        'inventory-issue-acknowledge',
                        {'id': issue.id},
                      ),
                      done: 'Receipt confirmed',
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Confirm receipt'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Return Items (Inspection)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record returned items split between usable and damaged stock.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (outstandingLines.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('All items have been fully returned.'),
            )
          else
            for (final item in outstandingLines) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentStockProvider.itemName(
                                    item.line.itemId,
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.line.batchNumber != null)
                                  Text(
                                    'Batch: ${item.line.batchNumber}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
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
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${formatQuantity(item.line.outstanding)} outstanding',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usable[item.index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Usable',
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.all_inclusive,
                                    size: 16,
                                  ),
                                  tooltip: 'All usable',
                                  onPressed: () {
                                    setState(() {
                                      _usable[item.index].text = formatQuantity(
                                        item.line.outstanding,
                                      );
                                      _damaged[item.index].text = '';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _damaged[item.index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Damaged',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (outstandingLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _returnedBy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Returned by (staff ERP ID)',
                hintText: 'e.g. 1024',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _return,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_return_rounded),
              label: Text(_busy ? 'Recording…' : 'Record Return'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
