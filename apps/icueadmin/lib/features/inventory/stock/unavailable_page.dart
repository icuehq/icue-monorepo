import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (mounted) {
      await context.read<StockProvider>().loadUnavailable(
        inventoryProvider.access,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final operate = context.watch<InventoryProvider>().access.can(
      'inventory.stock.operate',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Damaged / expired stock')),
      body: stockProvider.unavailable.isEmpty
          ? Center(
              child: stockProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(stockProvider.errorMessage ?? 'Nothing outstanding'),
            )
          : ListView(
              children: [
                for (final unavailable in stockProvider.unavailable)
                  ListTile(
                    title: Text(
                      '${stockProvider.itemName(unavailable.itemId)} × ${formatQuantity(unavailable.quantity)}',
                    ),
                    subtitle: Text(
                      '${humanizeStatus(unavailable.reason)}${unavailable.batchNumber == null ? '' : ' · batch ${unavailable.batchNumber}'}'
                      '${unavailable.remarks == null ? '' : '\n${unavailable.remarks}'}',
                    ),
                    isThreeLine: unavailable.remarks != null,
                    trailing: Text(humanizeStatus(unavailable.status)),
                    onTap: operate
                        ? () async {
                            await showFormSheet(
                              context,
                              () => _Resolve(unavailable),
                            );
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
  const _Resolve(this.unavailable);

  final InventoryUnavailable unavailable;

  @override
  State<_Resolve> createState() => _ResolveState();
}

class _ResolveState extends State<_Resolve> {
  final _remarks = TextEditingController();
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
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: _remarks,
        decoration: const InputDecoration(labelText: 'Note'),
      ),
      for (final mapEntry in _choices.entries)
        if (mapEntry.key != 'repair' ||
            (widget.unavailable.status == 'open' &&
                widget.unavailable.bucket == 'damaged'))
          ListTile(
            title: Text(mapEntry.value),
            onTap: () => stockSubmit(
              context,
              (stockProvider) =>
                  stockProvider.act('inventory-unavailable-resolve', {
                    'id': widget.unavailable.id,
                    'resolution': mapEntry.key,
                    'remarks': _remarks.text.trim(),
                  }, requestId: _requestId),
              done: 'Resolved',
            ),
          ),
    ],
  );
}
