import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';

/// One copy: details, label, and (for librarians) shelf / condition edit, move and status.
class CopyDialog extends StatefulWidget {
  const CopyDialog({super.key, required this.copy, required this.title});

  final LibraryCopy copy;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryCopy copy,
    String title,
  ) => showFormPage(context, () => CopyDialog(copy: copy, title: title));

  @override
  State<CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends State<CopyDialog> {
  late final _shelf = TextEditingController(text: widget.copy.shelf);
  late final _remarks = TextEditingController(text: widget.copy.remarks);
  late String _condition = widget.copy.condition;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_shelf, _remarks]) {
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
              AppTextField(controller: shelf, label: 'New shelf'),
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
              AppTextField(
                controller: reason,
                label: 'Reason (needed for damaged, lost, withdrawn)',
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
    final canEdit = libraryProvider.access.can('library.catalogue');
    final facts = <(String, String?)>[
      ('Status', humanizeStatus(copy.status)),
      ('Library', libraryProvider.library(copy.libraryId)?.name),
      ('Acquired', copy.acquiredDate?.toDisplayDay()),
      ('Price', copy.price.toRupees()),
    ];
    final theme = Theme.of(context);
    final shownFacts = [
      for (final fact in facts)
        if (fact.$2 != null && fact.$2!.isNotEmpty) fact,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  SelectableText(
                    copy.barcode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Print label',
              icon: const Icon(Icons.qr_code_2_rounded),
              onPressed: () => shareCopyLabels(widget.title, [copy]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              for (final fact in shownFacts)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.$1, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      fact.$2!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (canEdit) ...[
          const SizedBox(height: 24),
          Text('Edit details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AppTextField(controller: _shelf, label: 'Shelf / location'),
          const SizedBox(height: 16),
          AppDropdown<String>(
            value: _condition,
            items: [
              for (final copyCondition in copyConditions)
                DropdownMenuItem(
                  value: copyCondition,
                  child: Text(humanizeStatus(copyCondition)),
                ),
            ],
            onChanged: (value) => _condition = value!,
            label: 'Condition',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _remarks,
            label: 'Remarks (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save changes'),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => libraryProvider.updateCopy({
                          'id': copy.id,
                          'shelf': blankToNull(_shelf),
                          'condition': _condition,
                          'remarks': blankToNull(_remarks),
                        }),
                      ),
              ),
              if (copy.status == 'available')
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Move library'),
                  onPressed: _busy ? null : _move,
                ),
              if (copy.canChangeStatus)
                OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Change status'),
                  onPressed: _busy ? null : _status,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
