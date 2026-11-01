import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/copy_labels.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One copy: details, label, and (for librarians) shelf / condition / RFID edit, move and status.
class CopySheet extends StatefulWidget {
  const CopySheet({super.key, required this.copy, required this.title});

  final LibCopy copy;
  final String title;

  static Future<void> show(BuildContext context, LibCopy copy, String title) =>
      showInvSheet(context, () => CopySheet(copy: copy, title: title));

  @override
  State<CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<CopySheet> {
  late final _shelf = TextEditingController(text: widget.copy.shelf);
  late final _remarks = TextEditingController(text: widget.copy.remarks);
  late final _rfid = TextEditingController(text: widget.copy.rfidTag);
  late String _condition = widget.copy.condition;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_shelf, _remarks, _rfid]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Failed');
    }
  }

  Future<void> _move() async {
    final p = context.read<LibraryProvider>();
    final c = widget.copy;
    final libs = [
      for (final l in p.libraries)
        if (l.active &&
            l.id != c.libraryId &&
            p.access.campuses.contains(l.campusId))
          l,
    ];
    final shelf = TextEditingController();
    final to = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to another library'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in libs)
                ListTile(
                  title: Text(l.name),
                  onTap: () => Navigator.pop(ctx, l.id),
                ),
              if (libs.isEmpty) const Text('No other library available'),
              TextField(
                controller: shelf,
                decoration: const InputDecoration(labelText: 'New shelf'),
              ),
            ],
          ),
        ),
      ),
    );
    final newShelf = blankToNull(shelf);
    shelf.dispose();
    if (to == null || !mounted) return;
    await _run(() => p.moveCopy(c.id, to, newShelf));
  }

  Future<void> _status() async {
    final p = context.read<LibraryProvider>();
    final reason = TextEditingController();
    final s = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change status'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in copyManualStatuses)
                if (s != widget.copy.status)
                  ListTile(
                    title: Text(copyStatusLabel(s)),
                    onTap: () => Navigator.pop(ctx, s),
                  ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (needed for damaged, lost, withdrawn)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final why = blankToNull(reason);
    reason.dispose();
    if (s == null || !mounted) return;
    await _run(() => p.setCopyStatus(widget.copy.id, s, why));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<LibraryProvider>();
    final c = widget.copy;
    final canEdit = p.access.can('lib.catalogue.manage');
    final facts = <(String, String?)>[
      ('Status', copyStatusLabel(c.status)),
      ('Library', p.library(c.libraryId)?.name),
      ('Source', c.source),
      ('Vendor / donor', c.vendorOrDonor),
      ('Acquired', c.acquiredOn),
      ('Price', c.price.toStringAsFixed(2)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.accessionNo, style: Theme.of(context).textTheme.titleLarge),
        Text(widget.title),
        const SizedBox(height: 8),
        for (final f in facts)
          if (f.$2 != null && f.$2!.isNotEmpty)
            ListTile(dense: true, title: Text(f.$1), subtitle: Text(f.$2!)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Print label'),
            onPressed: () => shareCopyLabels(widget.title, [c]),
          ),
        ),
        if (canEdit) ...[
          const Divider(),
          TextField(
            controller: _shelf,
            decoration: const InputDecoration(labelText: 'Shelf / location'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _condition,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: [
              for (final x in copyConditions)
                DropdownMenuItem(value: x, child: Text(x)),
            ],
            onChanged: (v) => _condition = v!,
          ),
          TextField(
            controller: _rfid,
            decoration: const InputDecoration(labelText: 'RFID tag'),
          ),
          TextField(
            controller: _remarks,
            decoration: const InputDecoration(labelText: 'Remarks'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => p.updateCopy({
                      'id': c.id,
                      'shelf': blankToNull(_shelf),
                      'condition': _condition,
                      'rfidTag': blankToNull(_rfid),
                      'remarks': blankToNull(_remarks),
                    }),
                  ),
            child: const Text('Save'),
          ),
          if (c.status == 'available')
            TextButton(
              onPressed: _busy ? null : _move,
              child: const Text('Move to another library'),
            ),
          if (c.canChangeStatus)
            TextButton(
              onPressed: _busy ? null : _status,
              child: const Text('Change status'),
            ),
        ],
      ],
    );
  }
}
