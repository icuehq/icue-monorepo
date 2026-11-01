import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Actions on one balance: history, adjust, report damaged/expired/lost.
class BalanceActions extends StatelessWidget {
  const BalanceActions({required this.balance, super.key});

  final InvBalance balance;

  @override
  Widget build(BuildContext context) {
    final operate = context.read<InventoryProvider>().access.can(
      'inv.stock.operate',
    );
    final name = context.read<StockProvider>().itemName(balance.itemId);
    final nav = Navigator.of(context);
    Future<void> open(Widget Function() form) async {
      nav.pop();
      await showInvSheet(nav.context, form);
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
  const _History(this.b);

  final InvBalance b;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<InvMovement>>(
    future: context.read<StockProvider>().movements(b),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final rows = snap.data!;
      return SizedBox(
        height: 420,
        child: rows.isEmpty
            ? const Center(child: Text('No movements'))
            : ListView(
                children: [
                  for (final m in rows)
                    ListTile(
                      dense: true,
                      title: Text('${statusLabel(m.type)} · ${m.bucket}'),
                      subtitle: Text('${m.txnDate} · ${m.refType}'),
                      trailing: Text(
                        '${m.qty > 0 ? '+' : ''}${fmtQty(m.qty)}',
                        style: TextStyle(
                          color: m.qty < 0 ? Colors.red : Colors.green,
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
  const _BalanceForm(this.b);

  final InvBalance b;
}

mixin _Submit<T extends _BalanceForm> on State<T> {
  final form = GlobalKey<FormState>();
  final qty = TextEditingController();
  final note = TextEditingController();
  final requestId = newRequestId();

  Map<String, Object?> get key => {
    'storeId': widget.b.storeId,
    'itemId': widget.b.itemId,
    'variantId': ?widget.b.variantId,
    'batchNo': ?widget.b.batchNo,
  };

  Future<void> send(String fn, Map<String, Object?> extra) async {
    if (!form.currentState!.validate()) return;
    await stockSubmit(context, (p) async {
      final r = await p.act(fn, {...key, ...extra}, requestId: requestId);
      if (r != null && p.store != null) await p.loadBalances(p.store!);
      return r;
    });
  }

  @override
  void dispose() {
    qty.dispose();
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
      children: [
        Text('Currently ${fmtQty(widget.b.available)} available'),
        TextFormField(
          controller: qty,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Change (+ adds, − removes)',
          ),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            return n == null || n == 0 ? 'Enter a non-zero number' : null;
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: const InputDecoration(labelText: 'Reason'),
          items: [
            for (final e in _reasons.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _reason = v!),
        ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note'),
          validator: (v) => _reason == 'other' ? requiredText(v) : null,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => send('inv-adjustment-create', {
            'delta': double.parse(qty.text.trim()),
            'reason': _reason,
            'note': note.text.trim(),
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
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: const InputDecoration(labelText: 'What happened'),
          items: const [
            DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
            DropdownMenuItem(value: 'expired', child: Text('Expired')),
            DropdownMenuItem(value: 'lost', child: Text('Lost (written off)')),
          ],
          onChanged: (v) => setState(() => _reason = v!),
        ),
        TextFormField(
          controller: qty,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (max ${fmtQty(widget.b.available)})',
          ),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            return n == null || n <= 0 ? 'Enter a quantity' : null;
          },
        ),
        TextFormField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Details'),
          validator: requiredText,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => send('inv-unavailable-report', {
            'qty': double.parse(qty.text.trim()),
            'reason': _reason,
            'note': note.text.trim(),
          }),
          child: const Text('Report'),
        ),
      ],
    ),
  );
}
