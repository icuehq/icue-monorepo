import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// A transfer with its next workflow action: approve, dispatch or receive.
class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key, required this.transfer});

  final LibraryTransfer transfer;

  static Future<void> show(BuildContext context, LibraryTransfer transfer) =>
      showFormSheet(context, () => TransferSheet(transfer: transfer));

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  late final Set<String> _arrived = {
    for (final transferLine in widget.transfer.pending) transferLine.copyId,
  };
  bool _busy = false;

  Future<void> _run(
    Future<bool> Function(LibraryProvider libraryProvider) action,
  ) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    await submitAndClose<LibraryProvider>(
      context,
      () => action(libraryProvider),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final access = context.watch<LibraryProvider>().access;
    final manage = access.can('library.catalogue.manage');
    final receiving =
        transfer.status == 'dispatched' ||
        transfer.status == 'partially_received';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              transfer.number,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(label: Text(transferStatusLabel(transfer.status))),
          ],
        ),
        if (transfer.requestedDate != null)
          Text('Requested: ${transfer.requestedDate}'),
        if (transfer.dispatchedDate != null)
          Text('Dispatched: ${transfer.dispatchedDate}'),
        if (transfer.receivedDate != null)
          Text('Received: ${transfer.receivedDate}'),
        if (transfer.remarks != null) Text('Remarks: ${transfer.remarks}'),
        const Divider(height: 24),
        for (final transferLine in transfer.lineItems)
          if (receiving && !transferLine.received && manage)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(transferLine.accessionNumber),
              subtitle: const Text('In transit'),
              value: _arrived.contains(transferLine.copyId),
              onChanged: (value) => setState(
                () => value!
                    ? _arrived.add(transferLine.copyId)
                    : _arrived.remove(transferLine.copyId),
              ),
            )
          else
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(transferLine.accessionNumber),
              subtitle: Text(
                transferLine.received
                    ? 'Received (${transferLine.condition})'
                    : 'Not received',
              ),
            ),
        const SizedBox(height: 12),
        if (transfer.status == 'requested' && access.can('library.settings'))
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (libraryProvider) =>
                        libraryProvider.approveTransfer(transfer.id),
                  ),
            child: const Text('Approve'),
          ),
        if (transfer.status == 'approved' && manage)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (libraryProvider) =>
                        libraryProvider.dispatchTransfer(transfer.id),
                  ),
            child: const Text('Dispatch'),
          ),
        if (receiving && manage)
          FilledButton(
            onPressed: _busy || _arrived.isEmpty
                ? null
                : () => _run(
                    (libraryProvider) => libraryProvider.receiveTransfer({
                      'id': transfer.id,
                      'copies': [
                        for (final value in _arrived) {'copyId': value},
                      ],
                    }),
                  ),
            child: Text('Confirm receipt (${_arrived.length})'),
          ),
      ],
    );
  }
}
