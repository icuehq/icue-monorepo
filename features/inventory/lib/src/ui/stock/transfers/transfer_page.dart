import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:inventory/src/ui/stock/transfers/transfer_rules.dart';
import 'package:inventory/src/ui/stock/transfers/widgets/transfer_detail_widgets.dart';
import 'package:provider/provider.dart';

/// One stock transfer (FRS 10.10): dispatch at the source, then receive at the destination.
class StockTransferPage extends StatefulWidget {
  const StockTransferPage({required this.transferId, super.key});

  final String transferId;

  @override
  State<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends State<StockTransferPage> {
  final _remarks = TextEditingController();
  var _receive = <TextEditingController>[];
  var _signature = '';
  var _closeTransfer = false;
  var _loaded = false;
  var _busy = false;
  var _requestId = newRequestId();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _remarks.dispose();
    for (final controller in _receive) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final stockProvider = context.read<StockProvider>();
    await stockProvider.loadAllStores();
    if (mounted) await stockProvider.loadTransfers(inventoryProvider.access);
    if (mounted) setState(() => _loaded = true);
  }

  /// Fresh entry fields whenever the transfer's received quantities change.
  void _syncControllers(InventoryTransfer transfer) {
    final signature =
        '${transfer.id}|${transfer.status}|'
        '${transfer.lineItems.map((line) => line.received).join(',')}';
    if (signature == _signature) return;
    _signature = signature;
    final replaced = _receive;
    _receive = [
      for (final line in transfer.lineItems)
        TextEditingController(
          text: (line.dispatched - line.received).toQuantityText(),
        ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in replaced) {
        controller.dispose();
      }
    });
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: Size.zero),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  /// Runs [call], then reloads the transfers so the screen shows the new state.
  Future<bool> _run(
    Future<Map<String, dynamic>?> Function(StockProvider stockProvider) call,
    String done,
  ) async {
    final access = context.read<InventoryProvider>().access;
    setState(() => _busy = true);
    final succeeded = await stockSubmit(
      context,
      call,
      close: false,
      done: done,
    );
    if (succeeded) {
      // A transfer can be received in several parts; each needs its own key.
      _requestId = newRequestId();
      if (mounted) {
        await context.read<StockProvider>().loadTransfers(access);
      }
    }
    if (mounted) setState(() => _busy = false);
    return succeeded;
  }

  Future<void> _dispatch(
    InventoryTransfer transfer,
    String fromStoreName,
  ) async {
    final confirmed = await _confirm(
      'Dispatch transfer',
      'Dispatching deducts the quantities from $fromStoreName and keeps them '
          'in transit until the destination confirms receipt.',
      'Dispatch',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (stockProvider) => stockProvider.act('inventory-transfer-dispatch', {
        'id': transfer.id,
      }, requestId: _requestId),
      'Transfer dispatched',
    );
  }

  Future<void> _approve(InventoryTransfer transfer) async {
    final confirmed = await _confirm(
      'Approve transfer',
      'Approve ${transfer.number}? The source store can then dispatch the stock.',
      'Approve',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (stockProvider) => stockProvider.act('inventory-transfer-approve', {
        'id': transfer.id,
      }, requestId: _requestId),
      'Transfer approved',
    );
  }

  Future<void> _cancel(InventoryTransfer transfer) async {
    final reason = TextEditingController();
    final given = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${transfer.number}'),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: () => Navigator.pop(context, reason.text.trim()),
            child: const Text('Cancel transfer'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (given == null || given.isEmpty || !mounted) return;
    await _run(
      (provider) => provider.act('inventory-transfer-cancel', {
        'id': transfer.id,
        'reason': given,
      }, requestId: _requestId),
      'Transfer cancelled',
    );
  }

  Future<void> _confirmReceipt(InventoryTransfer transfer) async {
    final stockProvider = context.read<StockProvider>();
    final lineItems = <Map<String, Object?>>[];
    var shortfall = 0.0;
    for (final (index, line) in transfer.lineItems.indexed) {
      final remaining = line.dispatched - line.received;
      if (remaining <= 0) continue;
      final quantity = double.tryParse(_receive[index].text.trim()) ?? 0;
      if (quantity > remaining) {
        return showMessage(
          context,
          '${stockProvider.itemName(line.itemId)}: at most '
          '${remaining.toQuantityText()} can be received',
        );
      }
      shortfall += remaining - quantity;
      if (quantity > 0) {
        lineItems.add({'index': index, 'quantityReceived': quantity});
      }
    }
    if (lineItems.isEmpty && !_closeTransfer) {
      return showMessage(context, 'Enter the quantity received');
    }
    if (_closeTransfer && shortfall > 0) {
      final confirmed = await _confirm(
        'Close with shortfall',
        '${shortfall.toQuantityText()} units not received will be recorded as '
            'a permanent shortfall and the transfer closes.',
        'Close transfer',
      );
      if (!confirmed || !mounted) return;
    }
    final received = await _run(
      (provider) => provider.act('inventory-transfer-receive', {
        'id': transfer.id,
        'final': _closeTransfer,
        'remarks': ?blankToNull(_remarks),
        'lineItems': lineItems,
      }, requestId: _requestId),
      'Receipt recorded',
    );
    if (received && mounted) setState(() => _closeTransfer = false);
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final access = context.watch<InventoryProvider>().access;
    final theme = Theme.of(context);
    final transfer = stockProvider.transfers
        .where((candidate) => candidate.id == widget.transferId)
        .firstOrNull;

    if (transfer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer')),
        body: Center(
          child: !_loaded || stockProvider.isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stockProvider.errorMessage ?? 'Transfer not found'),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
    }

    _syncControllers(transfer);
    String storeName(String id) =>
        stockProvider.allStores
            .where((store) => store.id == id)
            .firstOrNull
            ?.name ??
        id;
    final canApprove = canApproveTransfer(transfer, access);
    final canDispatch = canDispatchTransfer(transfer, access);
    final canReceive = canReceiveTransfer(transfer, access);
    final waiting =
        !canApprove &&
        !canDispatch &&
        !canReceive &&
        transferWaitingFor(transfer).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(transfer.number),
        actions: [
          if (canCancelTransfer(transfer, access))
            TextButton(
              onPressed: _busy ? null : () => _cancel(transfer),
              child: const Text('Cancel transfer'),
            ),
        ],
      ),
      body: CenteredBody(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TransferSummaryCard(
                transfer: transfer,
                fromStoreName: storeName(transfer.fromStoreId),
                toStoreName: storeName(transfer.toStoreId),
              ),
              if (waiting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transferWaitingFor(transfer),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              TransferLinesCard(
                transfer: transfer,
                itemName: stockProvider.itemName,
                receiveControllers: canReceive ? _receive : null,
              ),
              if (canReceive) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Close transfer after this receipt'),
                  subtitle: const Text(
                    'Anything not received is recorded as a permanent shortfall',
                  ),
                  value: _closeTransfer,
                  onChanged: (value) => setState(() => _closeTransfer = value),
                ),
                TextField(
                  controller: _remarks,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Receipt remarks (optional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: canApprove || canDispatch || canReceive
          ? Material(
              elevation: 8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : canApprove
                        ? () => _approve(transfer)
                        : canDispatch
                        ? () => _dispatch(
                            transfer,
                            storeName(transfer.fromStoreId),
                          )
                        : () => _confirmReceipt(transfer),
                    icon: Icon(
                      canApprove
                          ? Icons.thumb_up_alt_outlined
                          : canDispatch
                          ? Icons.local_shipping_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      canApprove
                          ? 'Approve transfer'
                          : canDispatch
                          ? 'Dispatch transfer'
                          : 'Confirm receipt',
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
