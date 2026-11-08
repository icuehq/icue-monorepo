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
  late final _statusReason = TextEditingController();
  late String _condition = widget.copy.condition;
  late String _status = widget.copy.status;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_shelf, _remarks, _statusReason]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _statusRequiresReason(String status) =>
      status == 'damaged' || status == 'lost' || status == 'withdrawn';

  bool get _needsReason =>
      _status != widget.copy.status && _statusRequiresReason(_status);

  bool get _isTerminalStatus => _status == 'lost' || _status == 'withdrawn';

  List<String> get _availableStatuses {
    if (widget.copy.canChangeStatus) return copyManualStatuses;
    return copyManualStatuses.contains(widget.copy.status)
        ? copyManualStatuses
        : [widget.copy.status, ...copyManualStatuses];
  }

  String? _statusDisabledReason(String status) => switch (status) {
    'issued' => 'Cannot change status while issued to a member',
    'reserved' => 'Cannot change status while held for reservation',
    'in_transit' => 'Cannot change status while in transit',
    'lost' => 'Lost status is final and cannot be modified',
    'withdrawn' => 'Withdrawn status is final and cannot be modified',
    _ => 'Status cannot be changed manually',
  };

  (Color, Color) _statusColors(ThemeData theme, String status) {
    return switch (status) {
      'available' => (
        Colors.green.shade700,
        Colors.green.withValues(alpha: 0.12),
      ),
      'issued' => (
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      'reserved' => (
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'in_transit' => (
        Colors.amber.shade900,
        Colors.amber.withValues(alpha: 0.12),
      ),
      'under_maintenance' => (
        Colors.blue.shade700,
        Colors.blue.withValues(alpha: 0.12),
      ),
      'lost' || 'damaged' || 'withdrawn' => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
      _ => (Colors.grey.shade700, Colors.grey.withValues(alpha: 0.12)),
    };
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

  Future<void> _save() async {
    final statusChanged = _status != widget.copy.status;
    if (statusChanged && _needsReason && _statusReason.text.trim().isEmpty) {
      showMessage(
        context,
        'Please enter a reason for marking as ${humanizeStatus(_status).toLowerCase()}',
      );
      return;
    }

    final detailsChanged =
        _shelf.text.trim() != (widget.copy.shelf ?? '') ||
        _condition != widget.copy.condition ||
        _remarks.text.trim() != (widget.copy.remarks ?? '');

    if (!detailsChanged && !statusChanged) {
      Navigator.of(context).pop();
      return;
    }

    await _run(() async {
      final libraryProvider = context.read<LibraryProvider>();
      if (detailsChanged) {
        final ok = await libraryProvider.updateCopy({
          'id': widget.copy.id,
          'shelf': blankToNull(_shelf),
          'condition': _condition,
          'remarks': blankToNull(_remarks),
        });
        if (!ok) return false;
      }
      if (statusChanged) {
        final ok = await libraryProvider.setCopyStatus(
          widget.copy.id,
          _status,
          blankToNull(_statusReason),
        );
        if (!ok) return false;
      }
      return true;
    });
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
    if (libraries.isEmpty) {
      showMessage(
        context,
        'No other active library available to move this copy to',
      );
      return;
    }

    String selectedLibraryId = libraries.first.id;
    final shelf = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Move to another library'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDropdown<String>(
                  value: selectedLibraryId,
                  items: [
                    for (final schoolLibrary in libraries)
                      DropdownMenuItem(
                        value: schoolLibrary.id,
                        child: Text(schoolLibrary.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedLibraryId = value);
                    }
                  },
                  label: 'Destination library',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: shelf,
                  label: 'Shelf in new library (optional)',
                  hintText: 'e.g. Rack A',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move copy'),
            ),
          ],
        ),
      ),
    );
    final newShelf = blankToNull(shelf);
    shelf.dispose();
    if (confirmed != true || !mounted) return;
    await _run(
      () => libraryProvider.moveCopy(copy.id, selectedLibraryId, newShelf),
    );
  }

  Widget _statusPill(ThemeData theme, String status) {
    final (textColor, backgroundColor) = _statusColors(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        humanizeStatus(status),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = widget.copy;
    final facts = <(String, String?)>[
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          SelectableText(
                            copy.barcode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _statusPill(theme, copy.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Print barcode label',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => shareCopyLabels(widget.title, [copy]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              for (final fact in shownFacts)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact.$1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fact.$2!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Edit details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _shelf,
          label: 'Shelf / location',
          hintText: 'e.g. Rack A, Shelf 3',
        ),
        const SizedBox(height: 14),
        AppDropdown<String>(
          value: _status,
          items: [
            for (final status in _availableStatuses)
              DropdownMenuItem(
                value: status,
                child: Text(humanizeStatus(status)),
              ),
          ],
          onChanged: copy.canChangeStatus
              ? (value) {
                  if (value != null) setState(() => _status = value);
                }
              : null,
          label: 'Status',
          helperText: !copy.canChangeStatus
              ? _statusDisabledReason(copy.status)
              : null,
        ),
        if (_status != widget.copy.status && _isTerminalStatus) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Marking as ${humanizeStatus(_status).toLowerCase()} is permanent and cannot be undone.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_status != widget.copy.status) ...[
          const SizedBox(height: 14),
          AppTextField(
            controller: _statusReason,
            label: _needsReason
                ? 'Reason for status change *'
                : 'Reason for status change (optional)',
            hintText: _needsReason
                ? 'Required when marking as ${humanizeStatus(_status).toLowerCase()}'
                : 'Optional note for audit history',
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 14),
        AppDropdown<String>(
          value: _condition,
          items: [
            for (final copyCondition in copyConditions)
              DropdownMenuItem(
                value: copyCondition,
                child: Text(humanizeStatus(copyCondition)),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _condition = value);
          },
          label: 'Condition',
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _remarks,
          label: 'Remarks (optional)',
          hintText: 'Notes regarding copy condition or history',
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_busy ? 'Saving…' : 'Save changes'),
              onPressed: _busy ? null : _save,
            ),
            if (copy.status == 'available' && _status == 'available')
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Move library'),
                onPressed: _busy ? null : _move,
              ),
          ],
        ),
      ],
    );
  }
}
