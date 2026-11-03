import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Actions on one balance: history, adjust, report damaged/expired/lost.
class BalanceActions extends StatelessWidget {
  const BalanceActions({required this.balance, super.key});

  final InventoryBalance balance;

  @override
  Widget build(BuildContext context) {
    final operate = context.read<InventoryProvider>().access.can(
      'inventory.stock.operate',
    );
    final name = context.read<StockProvider>().itemName(balance.itemId);
    final navigator = Navigator.of(context);
    Future<void> open(Widget Function() form) async {
      navigator.pop();
      await showFormSheet(navigator.context, form);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          leading: const Icon(Icons.history_rounded),
          title: const Text('Movement history'),
          onTap: () => open(() => _History(balance)),
        ),
        if (operate) ...[
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Adjust quantity'),
            onTap: () => open(() => _Adjust(balance)),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: const Text('Report damaged / expired / lost'),
            onTap: () => open(() => _Report(balance)),
          ),
        ],
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History(this.balance);

  final InventoryBalance balance;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<InventoryMovement>>(
    future: context.read<StockProvider>().movements(balance),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final rows = snapshot.data!;
      return SizedBox(
        height: 420,
        child: rows.isEmpty
            ? const Center(child: Text('No movements'))
            : ListView(
                children: [
                  for (final movement in rows)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${humanizeStatus(movement.type)} · ${movement.bucket}',
                      ),
                      subtitle: Text(
                        '${movement.transactionDate} · ${movement.referenceType}',
                      ),
                      trailing: Text(
                        '${movement.quantity > 0 ? '+' : ''}${formatQuantity(movement.quantity)}',
                        style: TextStyle(
                          color: movement.quantity < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

abstract class _BalanceForm extends StatefulWidget {
  const _BalanceForm(this.balance);

  final InventoryBalance balance;
}

mixin _Submit<T extends _BalanceForm> on State<T> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController();
  final note = TextEditingController();
  final requestId = newRequestId();

  Map<String, Object?> get key => {
    'storeId': widget.balance.storeId,
    'itemId': widget.balance.itemId,
    'variantId': ?widget.balance.variantId,
    'batchNumber': ?widget.balance.batchNumber,
  };

  Future<void> send(String value, Map<String, Object?> extra) async {
    if (!form.currentState!.validate()) return;
    await stockSubmit(context, (stockProvider) async {
      final row = await stockProvider.act(value, {
        ...key,
        ...extra,
      }, requestId: requestId);
      if (row != null && stockProvider.store != null) {
        await stockProvider.loadBalances(stockProvider.store!);
      }
      return row;
    });
  }

  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }
}

class _Adjust extends _BalanceForm {
  const _Adjust(super.b);

  @override
  State<_Adjust> createState() => _AdjustState();
}

class _AdjustState extends State<_Adjust> with _Submit {
  var _reason = 'count_correction';
  static const _reasons = {
    'count_correction': 'Physical count correction',
    'data_entry': 'Data entry correction',
    'missing': 'Missing stock',
    'excess': 'Excess stock',
    'other': 'Other (describe)',
  };

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text('Currently ${formatQuantity(widget.balance.available)} available'),
        TextFormField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Change (+ adds, − removes)',
          ),
          validator: (value) {
            final number = double.tryParse((value ?? '').trim());
            return number == null || number == 0
                ? 'Enter a non-zero number'
                : null;
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Reason'),
          items: [
            for (final mapEntry in _reasons.entries)
              DropdownMenuItem(
                value: mapEntry.key,
                child: Text(mapEntry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _reason = value!),
        ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note'),
          validator: (value) => _reason == 'other' ? requiredText(value) : null,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => send('inventory-adjustment-create', {
            'delta': double.parse(quantity.text.trim()),
            'reason': _reason,
            'remarks': note.text.trim(),
          }),
          child: const Text('Apply adjustment'),
        ),
      ],
    ),
  );
}

class _Report extends _BalanceForm {
  const _Report(super.b);

  @override
  State<_Report> createState() => _ReportState();
}

class _ReportState extends State<_Report> with _Submit {
  var _reason = 'damaged';

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'What happened'),
          items: const [
            DropdownMenuItem(
              value: 'damaged',
              child: Text('Damaged', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'expired',
              child: Text('Expired', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'lost',
              child: Text(
                'Lost (written off)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) => setState(() => _reason = value!),
        ),
        TextFormField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Quantity (max ${formatQuantity(widget.balance.available)})',
          ),
          validator: (value) {
            final number = double.tryParse((value ?? '').trim());
            return number == null || number <= 0 ? 'Enter a quantity' : null;
          },
        ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Details'),
          validator: requiredText,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => send('inventory-unavailable-report', {
            'quantity': double.parse(quantity.text.trim()),
            'reason': _reason,
            'remarks': note.text.trim(),
          }),
          child: const Text('Report'),
        ),
      ],
    ),
  );
}
