import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// A transfer with its next workflow action: approve, dispatch or receive.
class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key, required this.transfer});

  final LibTransfer transfer;

  static Future<void> show(BuildContext context, LibTransfer t) =>
      showInvSheet(context, () => TransferSheet(transfer: t));

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  late final Set<String> _arrived = {
    for (final l in widget.transfer.pending) l.copyId,
  };
  bool _busy = false;

  Future<void> _run(Future<bool> Function(LibraryProvider p) action) async {
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    await libSubmit(context, () => action(p));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final access = context.watch<LibraryProvider>().access;
    final manage = access.can('lib.catalogue.manage');
    final receiving =
        t.status == 'dispatched' || t.status == 'partially_received';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t.number, style: Theme.of(context).textTheme.titleMedium),
            Chip(label: Text(transferStatusLabel(t.status))),
          ],
        ),
        if (t.requestedOn != null) Text('Requested: ${t.requestedOn}'),
        if (t.dispatchedOn != null) Text('Dispatched: ${t.dispatchedOn}'),
        if (t.receivedOn != null) Text('Received: ${t.receivedOn}'),
        if (t.remarks != null) Text('Remarks: ${t.remarks}'),
        const Divider(height: 24),
        for (final l in t.lines)
          if (receiving && !l.received && manage)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.accessionNo),
              subtitle: const Text('In transit'),
              value: _arrived.contains(l.copyId),
              onChanged: (v) => setState(
                () => v! ? _arrived.add(l.copyId) : _arrived.remove(l.copyId),
              ),
            )
          else
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.accessionNo),
              subtitle: Text(
                l.received ? 'Received (${l.condition})' : 'Not received',
              ),
            ),
        const SizedBox(height: 12),
        if (t.status == 'requested' && access.can('lib.settings'))
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run((p) => p.approveTransfer(t.id)),
            child: const Text('Approve'),
          ),
        if (t.status == 'approved' && manage)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run((p) => p.dispatchTransfer(t.id)),
            child: const Text('Dispatch'),
          ),
        if (receiving && manage)
          FilledButton(
            onPressed: _busy || _arrived.isEmpty
                ? null
                : () => _run(
                    (p) => p.receiveTransfer({
                      'id': t.id,
                      'copies': [
                        for (final c in _arrived) {'copyId': c},
                      ],
                    }),
                  ),
            child: Text('Confirm receipt (${_arrived.length})'),
          ),
      ],
    );
  }
}
