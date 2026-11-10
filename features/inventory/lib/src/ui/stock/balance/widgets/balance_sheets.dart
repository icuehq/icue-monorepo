import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:inventory/src/ui/stock/shared/stock_validators.dart';
import 'package:provider/provider.dart';

/// Movement ledger of one balance.
class MovementHistory extends StatelessWidget {
  const MovementHistory(this.balance, {super.key});

  final InventoryBalance balance;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<InventoryMovement>>(
    future: context.read<StockProvider>().movements(balance),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final rows = snapshot.data!;
      return rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No movements yet')),
            )
          : Column(
              children: [
                for (final movement in rows)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${humanizeStatus(movement.type)} · ${movement.bucket}',
                    ),
                    subtitle: Text(
                      '${movement.transactionDate.toDisplayDay()} · ${movement.referenceType}',
                    ),
                    trailing: Text(
                      '${movement.quantity > 0 ? '+' : ''}${movement.quantity.toQuantityText()}',
                      style: TextStyle(
                        color: movement.quantity < 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ),
              ],
            );
    },
  );
}

abstract class _BalanceForm extends StatefulWidget {
  const _BalanceForm(this.balance, {super.key});

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

class AdjustStockForm extends _BalanceForm {
  const AdjustStockForm(super.balance, {super.key});

  @override
  State<AdjustStockForm> createState() => _AdjustState();
}

class _AdjustState extends State<AdjustStockForm> with _Submit {
  var _add = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = widget.balance.available;
    return Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text.rich(
            TextSpan(
              text: 'In stock now: ',
              children: [
                TextSpan(
                  text: available.toQuantityText(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: theme.textTheme.bodyLarge,
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.add_rounded),
                label: Text('Add stock'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.remove_rounded),
                label: Text('Remove stock'),
              ),
            ],
            selected: {_add},
            onSelectionChanged: (value) => setState(() {
              _add = value.first;
              form.currentState?.validate();
            }),
          ),
          IcueTextField(
            controller: quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: quantityFormatters,
            validator: (value) {
              final error = validateQuantity(value);
              if (error != null) return error;
              if (!_add && double.parse(value!.trim()) > available) {
                return 'Only ${available.toQuantityText()} in stock';
              }
              return null;
            },
            label: _add ? 'Quantity to add' : 'Quantity to remove',
          ),
          IcueTextField(
            controller: note,
            label: 'Note (optional)',
            maxLength: 500,
          ),
          IcueButton(
            label: _add ? 'Add stock' : 'Remove stock',
            onPressed: () => send('inventory-adjustment-create', {
              'delta': (_add ? 1 : -1) * double.parse(quantity.text.trim()),
              'reason': 'count_correction',
              'remarks': note.text.trim(),
            }),
          ),
        ],
      ),
    );
  }
}

class ReportStockForm extends _BalanceForm {
  const ReportStockForm(super.balance, {super.key});

  @override
  State<ReportStockForm> createState() => _ReportState();
}

class _ReportState extends State<ReportStockForm> with _Submit {
  var _reason = 'damaged';

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        IcueDropdown<String>(
          value: _reason,
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
          label: 'What happened',
        ),
        IcueTextField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final number = double.tryParse((value ?? '').trim());
            return number == null || number <= 0 ? 'Enter a quantity' : null;
          },
          label: 'Quantity (max ${widget.balance.available.toQuantityText()})',
        ),
        IcueTextField(
          controller: note,
          validator: requiredText,
          label: 'Details',
        ),
        const SizedBox(height: 12),
        IcueButton(
          label: 'Report',
          onPressed: () => send('inventory-unavailable-report', {
            'quantity': double.parse(quantity.text.trim()),
            'reason': _reason,
            'remarks': note.text.trim(),
          }),
        ),
      ],
    ),
  );
}
