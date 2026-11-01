import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Open damaged / expired stock (FRS 10.12) and how it is resolved.
class UnavailablePage extends StatefulWidget {
  const UnavailablePage({super.key});

  @override
  State<UnavailablePage> createState() => _UnavailablePageState();
}

class _UnavailablePageState extends State<UnavailablePage> {
  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.stores.isEmpty) await inv.loadMasters();
    if (mounted) {
      await context.read<StockProvider>().loadUnavailable(inv.access);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StockProvider>();
    final operate = context.watch<InventoryProvider>().access.can(
      'inv.stock.operate',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Damaged / expired stock')),
      body: p.unavailable.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'Nothing outstanding'),
            )
          : ListView(
              children: [
                for (final u in p.unavailable)
                  ListTile(
                    title: Text('${p.itemName(u.itemId)} × ${fmtQty(u.qty)}'),
                    subtitle: Text(
                      '${statusLabel(u.reason)}${u.batchNo == null ? '' : ' · batch ${u.batchNo}'}'
                      '${u.note == null ? '' : '\n${u.note}'}',
                    ),
                    isThreeLine: u.note != null,
                    trailing: Text(statusLabel(u.status)),
                    onTap: operate
                        ? () async {
                            await showInvSheet(context, () => _Resolve(u));
                            if (mounted) await _load();
                          }
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _Resolve extends StatefulWidget {
  const _Resolve(this.u);

  final InvUnavailable u;

  @override
  State<_Resolve> createState() => _ResolveState();
}

class _ResolveState extends State<_Resolve> {
  final _note = TextEditingController();
  final _requestId = newRequestId();

  static const _choices = {
    'restore': 'Return to usable stock (after inspection)',
    'repair': 'Send for repair',
    'dispose': 'Dispose',
    'write_off': 'Write off',
    'vendor_return': 'Return to vendor',
    'other': 'Other (describe)',
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: _note,
        decoration: const InputDecoration(labelText: 'Note'),
      ),
      for (final e in _choices.entries)
        if (e.key != 'repair' ||
            (widget.u.status == 'open' && widget.u.bucket == 'damaged'))
          ListTile(
            title: Text(e.value),
            onTap: () => stockSubmit(
              context,
              (p) => p.act('inv-unavailable-resolve', {
                'id': widget.u.id,
                'resolution': e.key,
                'note': _note.text.trim(),
              }, requestId: _requestId),
              done: 'Resolved',
            ),
          ),
    ],
  );
}
