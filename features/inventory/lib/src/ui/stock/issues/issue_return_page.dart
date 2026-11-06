import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_widgets.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Records a return against one issue, split usable / damaged on inspection (FRS 10.9).
class IssueReturnPage extends StatefulWidget {
  const IssueReturnPage({required this.issue, super.key});

  final InventoryIssue issue;

  @override
  State<IssueReturnPage> createState() => _IssueReturnPageState();
}

class _IssueReturnPageState extends State<IssueReturnPage> {
  late final _usable = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  late final _damaged = [
    for (final _ in widget.issue.lineItems) TextEditingController(),
  ];
  final _requestId = newRequestId();
  late int? _returnedBy = widget.issue.recipientType == 'staff'
      ? widget.issue.recipientId
      : null;
  var _busy = false;

  @override
  void dispose() {
    for (final controller in [..._usable, ..._damaged]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save() async {
    final returnedBy = _returnedBy;
    if (returnedBy == null) {
      return showMessage(context, 'Choose who is returning the items');
    }
    final stockProvider = context.read<StockProvider>();
    final lineItems = <Map<String, Object?>>[];
    for (final (index, line) in widget.issue.lineItems.indexed) {
      final usable = _number(_usable[index]);
      final damaged = _number(_damaged[index]);
      if (usable + damaged <= 0) continue;
      if (usable + damaged > line.outstanding) {
        return showMessage(
          context,
          '${stockProvider.itemName(line.itemId)}: only '
          '${line.outstanding.toQuantityText()} can still be returned',
        );
      }
      lineItems.add({
        'balanceId': line.balanceId,
        'quantityUsable': usable,
        'quantityDamaged': damaged,
      });
    }
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter a returned quantity');
    }
    setState(() => _busy = true);
    final saved = await stockSubmit(
      context,
      (provider) => provider.act('inventory-return-create', {
        'issueId': widget.issue.id,
        'returnedBy': {'type': 'staff', 'personErpId': returnedBy},
        'lineItems': lineItems,
      }, requestId: _requestId),
      done: 'Return recorded',
    );
    if (!saved && mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.read<StockProvider>();
    final issue = widget.issue;
    final returnedBy = _returnedBy;
    final numberInput = [decimalInputFormatter];
    const decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(title: Text('Return · ${issue.number}')),
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Count what came back and split it between usable stock and damaged goods.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, line) in issue.lineItems.indexed)
              if (line.outstanding > 0)
                IssueSection(
                  title: stockProvider.itemName(line.itemId),
                  trailing: Text(
                    '${line.outstanding.toQuantityText()} to return',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (line.batchNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Batch ${line.batchNumber}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _usable[index],
                              keyboardType: decimalKeyboard,
                              inputFormatters: numberInput,
                              label: 'Usable',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.done_all, size: 18),
                                tooltip: 'All usable',
                                onPressed: () {
                                  _usable[index].text = line.outstanding
                                      .toQuantityText();
                                  _damaged[index].clear();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppTextField(
                              controller: _damaged[index],
                              keyboardType: decimalKeyboard,
                              inputFormatters: numberInput,
                              label: 'Damaged',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            IssueSection(
              title: 'Returned by',
              child: returnedBy != null
                  ? InputChip(
                      avatar: const Icon(Icons.person_rounded, size: 18),
                      label: Text(staffDisplayName(returnedBy)),
                      onDeleted: () => setState(() => _returnedBy = null),
                    )
                  : PersonSearchField(
                      label: 'Staff member',
                      hint: 'Search by name or enter an ID…',
                      onSelected: (person) =>
                          setState(() => _returnedBy = person.id),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.assignment_return_rounded),
              label: Text(_busy ? 'Recording…' : 'Record return'),
            ),
          ),
        ),
      ),
    );
  }
}
