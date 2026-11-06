import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/transfers/widgets/transfer_detail_widgets.dart';
import 'package:school_library/src/ui/transfers/widgets/transfer_widgets.dart';

/// One transfer (FRS 11.15) with its next step: approve, dispatch or confirm receipt.
class LibraryTransferPage extends StatefulWidget {
  const LibraryTransferPage({required this.transferId, super.key});

  final String transferId;

  @override
  State<LibraryTransferPage> createState() => _LibraryTransferPageState();
}

class _LibraryTransferPageState extends State<LibraryTransferPage> {
  final _shelf = TextEditingController();
  final _remarks = TextEditingController();

  /// Copies the receiver unticked (still missing); everything pending is ticked by default.
  final _missing = <String>{};
  final _conditions = <String, String>{};
  var _loaded = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _shelf.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    if (libraryProvider.libraries.isEmpty) await libraryProvider.loadMasters();
    await libraryProvider.loadTransfers();
    if (mounted) setState(() => _loaded = true);
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

  /// Runs [action]; the provider reloads the list on success, which refreshes this screen.
  Future<void> _run(
    Future<bool> Function(LibraryProvider libraryProvider) action,
    String done,
  ) async {
    final libraryProvider = context.read<LibraryProvider>();
    setState(() => _busy = true);
    final succeeded = await action(libraryProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(
      context,
      succeeded ? done : libraryProvider.errorMessage ?? 'Could not save',
    );
  }

  Future<String?> _askReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 500,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason == null || reason.isEmpty ? null : reason;
  }

  Future<void> _cancel(LibraryTransfer transfer) async {
    final reason = await _askReason('Cancel ${transfer.number}');
    if (reason == null || !mounted) return;
    await _run(
      (libraryProvider) => libraryProvider.cancelTransfer(transfer.id, reason),
      'Transfer cancelled',
    );
  }

  Future<void> _closeShort(LibraryTransfer transfer) async {
    final reason = await _askReason(
      'Close short: ${transfer.pending.length} copies not received',
    );
    if (reason == null || !mounted) return;
    await _run(
      (libraryProvider) =>
          libraryProvider.closeTransferShort(transfer.id, reason),
      'Transfer closed; missing copies marked lost',
    );
  }

  Future<void> _approve(LibraryTransfer transfer) async {
    final confirmed = await _confirm(
      'Approve transfer',
      'Approve ${transfer.number}? The source library can then dispatch the copies.',
      'Approve',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (libraryProvider) => libraryProvider.approveTransfer(transfer.id),
      'Transfer approved',
    );
  }

  Future<void> _dispatch(LibraryTransfer transfer) async {
    final confirmed = await _confirm(
      'Dispatch copies',
      'Dispatch ${transfer.lineItems.length} copies? They leave circulation '
          'and cannot be issued until the destination receives them.',
      'Dispatch',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (libraryProvider) => libraryProvider.dispatchTransfer(transfer.id),
      'Copies dispatched',
    );
  }

  Future<void> _receive(
    LibraryTransfer transfer,
    List<LibraryTransferLine> arrived,
  ) async {
    final stillMissing = transfer.pending.length - arrived.length;
    if (stillMissing > 0) {
      final confirmed = await _confirm(
        'Receive part of the transfer',
        '$stillMissing ${stillMissing == 1 ? 'copy stays' : 'copies stay'} '
            'in transit and can be received later.',
        'Receive',
      );
      if (!confirmed || !mounted) return;
    }
    await _run((libraryProvider) async {
      final succeeded = await libraryProvider.receiveTransfer({
        'id': transfer.id,
        'copies': [
          for (final line in arrived)
            {
              'copyId': line.copyId,
              'condition': _conditions[line.copyId] ?? 'good',
            },
        ],
        'shelf': ?blankToNull(_shelf),
        'remarks': ?blankToNull(_remarks),
      });
      if (succeeded) _missing.clear();
      return succeeded;
    }, 'Receipt confirmed');
  }

  Widget? _actionBar(
    LibraryTransfer transfer,
    ModuleAccess access,
    List<LibraryTransferLine> arrived,
  ) {
    final VoidCallback? onPressed;
    final String label;
    if (canApproveTransfer(transfer, access)) {
      onPressed = () => _approve(transfer);
      label = 'Approve transfer';
    } else if (canDispatchTransfer(transfer, access)) {
      onPressed = () => _dispatch(transfer);
      label = 'Dispatch copies';
    } else if (canReceiveTransfer(transfer, access)) {
      onPressed = arrived.isEmpty ? null : () => _receive(transfer, arrived);
      label = 'Confirm receipt (${arrived.length})';
    } else {
      return null;
    }
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(
            onPressed: _busy ? null : onPressed,
            child: Text(label),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final access = libraryProvider.access;
    final transfer = libraryProvider.transfers
        .where((candidate) => candidate.id == widget.transferId)
        .firstOrNull;

    if (transfer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer')),
        body: Center(
          child: !_loaded || libraryProvider.transfersLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(libraryProvider.errorMessage ?? 'Transfer not found'),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
    }

    final theme = Theme.of(context);
    final receiving = canReceiveTransfer(transfer, access);
    final arrived = [
      for (final line in transfer.pending)
        if (!_missing.contains(line.copyId)) line,
    ];
    final waiting =
        transferNextAction(transfer, access) == null &&
        transferWaitingFor(transfer).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(transfer.number),
        actions: [
          if ((transfer.status == 'requested' ||
                  transfer.status == 'approved') &&
              access.can('library.catalogue') &&
              onCampus(access, transfer.campusId))
            TextButton(
              onPressed: _busy ? null : () => _cancel(transfer),
              child: const Text('Cancel transfer'),
            ),
          if (receiving)
            TextButton(
              onPressed: _busy ? null : () => _closeShort(transfer),
              child: const Text('Close short'),
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
              TransferSummary(
                transfer: transfer,
                fromName:
                    libraryProvider.library(transfer.fromLibraryId)?.name ??
                    transfer.fromLibraryId,
                toName:
                    libraryProvider.library(transfer.toLibraryId)?.name ??
                    transfer.toLibraryId,
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
              Card(
                elevation: 0,
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
                              'Copies (${transfer.lineItems.length})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (receiving)
                            TextButton(
                              onPressed: () => setState(() {
                                if (arrived.length == transfer.pending.length) {
                                  _missing.addAll(
                                    transfer.pending.map((line) => line.copyId),
                                  );
                                } else {
                                  _missing.clear();
                                }
                              }),
                              child: Text(
                                arrived.length == transfer.pending.length
                                    ? 'Clear all'
                                    : 'Select all',
                              ),
                            ),
                        ],
                      ),
                      for (final line in transfer.lineItems)
                        if (receiving && !line.received)
                          TransferReceiveRow(
                            line: line,
                            selected: !_missing.contains(line.copyId),
                            condition: _conditions[line.copyId] ?? 'good',
                            onSelected: (value) => setState(
                              () => value
                                  ? _missing.remove(line.copyId)
                                  : _missing.add(line.copyId),
                            ),
                            onCondition: (value) => setState(
                              () => _conditions[line.copyId] = value,
                            ),
                          )
                        else
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              line.received
                                  ? Icons.check_circle_rounded
                                  : Icons.local_shipping_outlined,
                              color: line.received
                                  ? Colors.green.shade700
                                  : theme.colorScheme.outline,
                            ),
                            title: Text(line.accessionNumber),
                            subtitle: Text(
                              line.received
                                  ? 'Received${line.condition == null ? '' : ' · ${line.condition} condition'}'
                                  : transfer.status == 'requested' ||
                                        transfer.status == 'approved'
                                  ? 'Not dispatched yet'
                                  : 'In transit',
                            ),
                          ),
                      if (receiving) ...[
                        const Divider(height: 24),
                        TextField(
                          controller: _shelf,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Shelf (optional)',
                            helperText: 'Where the received copies are placed',
                          ),
                        ),
                        const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(transfer, access, arrived),
    );
  }
}
