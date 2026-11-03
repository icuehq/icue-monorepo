import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';

/// One copy: details, label, and (for librarians) shelf / condition / RFID edit, move and status.
class CopySheet extends StatefulWidget {
  const CopySheet({super.key, required this.copy, required this.title});

  final LibraryCopy copy;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryCopy copy,
    String title,
  ) => showFormPage(context, () => CopySheet(copy: copy, title: title));

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
    for (final controller in [_shelf, _remarks, _rfid]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
  }

  Future<void> _move() async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = widget.copy;
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active &&
            schoolLibrary.id != copy.libraryId &&
            libraryProvider.access.campusIds.contains(schoolLibrary.campusId))
          schoolLibrary,
    ];
    final shelf = TextEditingController();
    final to = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to another library'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final schoolLibrary in libraries)
                ListTile(
                  title: Text(schoolLibrary.name),
                  onTap: () => Navigator.pop(context, schoolLibrary.id),
                ),
              if (libraries.isEmpty) const Text('No other library available'),
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
    await _run(() => libraryProvider.moveCopy(copy.id, to, newShelf));
  }

  Future<void> _status() async {
    final libraryProvider = context.read<LibraryProvider>();
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change status'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final copyManualStatus in copyManualStatuses)
                if (copyManualStatus != widget.copy.status)
                  ListTile(
                    title: Text(humanizeStatus(copyManualStatus)),
                    onTap: () => Navigator.pop(context, copyManualStatus),
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
    final reasonText = blankToNull(reason);
    reason.dispose();
    if (value == null || !mounted) return;
    await _run(
      () => libraryProvider.setCopyStatus(widget.copy.id, value, reasonText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = widget.copy;
    final canEdit = libraryProvider.access.can('library.catalogue.manage');
    final facts = <(String, String?)>[
      ('Status', humanizeStatus(copy.status)),
      ('Library', libraryProvider.library(copy.libraryId)?.name),
      ('Source', copy.source),
      ('Vendor / donor', copy.vendorOrDonor),
      ('Acquired', copy.acquiredDate?.toDisplayDay()),
      ('Price', copy.price.toRupees()),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.accessionNumber,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(widget.title),
        const SizedBox(height: 8),
        for (final fact in facts)
          if (fact.$2 != null && fact.$2!.isNotEmpty)
            ListTile(
              dense: true,
              title: Text(fact.$1),
              subtitle: Text(fact.$2!),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Print label'),
            onPressed: () => shareCopyLabels(widget.title, [copy]),
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
              for (final copyCondition in copyConditions)
                DropdownMenuItem(
                  value: copyCondition,
                  child: Text(copyCondition),
                ),
            ],
            onChanged: (value) => _condition = value!,
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
                    () => libraryProvider.updateCopy({
                      'id': copy.id,
                      'shelf': blankToNull(_shelf),
                      'condition': _condition,
                      'rfidTag': blankToNull(_rfid),
                      'remarks': blankToNull(_remarks),
                    }),
                  ),
            child: const Text('Save'),
          ),
          if (copy.status == 'available')
            TextButton(
              onPressed: _busy ? null : _move,
              child: const Text('Move to another library'),
            ),
          if (copy.canChangeStatus)
            TextButton(
              onPressed: _busy ? null : _status,
              child: const Text('Change status'),
            ),
        ],
      ],
    );
  }
}
