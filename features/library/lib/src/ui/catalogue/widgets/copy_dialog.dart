import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// One copy: details, label, and (for librarians) shelf / condition edit and status.
class CopyDialog extends StatefulWidget {
  const CopyDialog({super.key, required this.copy, required this.title});

  final LibraryCopy copy;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryCopy copy,
    String title,
  ) => showDialog<void>(
    context: context,
    builder: (_) => CopyDialog(copy: copy, title: title),
  );

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
      status == CopyStatus.damaged ||
      status == CopyStatus.lost ||
      status == CopyStatus.withdrawn;

  bool get _needsReason =>
      _status != widget.copy.status && _statusRequiresReason(_status);

  bool get _isTerminalStatus => terminalCopyStatuses.contains(_status);

  List<String> get _availableStatuses {
    if (widget.copy.canChangeStatus) return manualCopyStatuses;
    return manualCopyStatuses.contains(widget.copy.status)
        ? manualCopyStatuses
        : [widget.copy.status, ...manualCopyStatuses];
  }

  String? _statusDisabledReason(String status) => switch (status) {
    CopyStatus.issued => 'Cannot change status while issued to a member',
    CopyStatus.lost => 'Lost status is final and cannot be modified',
    CopyStatus.withdrawn => 'Withdrawn status is final and cannot be modified',
    _ => 'Status cannot be changed manually',
  };

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
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
      Navigator.of(context, rootNavigator: true).pop();
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

    final content = Column(
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
                      LibraryStatusChip(copy.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Print barcode label',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => shareCopyLabels(widget.title, [
                (barcode: copy.barcode, shelf: copy.shelf),
              ]),
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
        IcueTextField(
          controller: _shelf,
          label: 'Shelf / location',
          hintText: 'e.g. Rack A, Shelf 3',
        ),
        const SizedBox(height: 14),
        IcueDropdown<String>(
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
          IcueTextField(
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
        IcueDropdown<String>(
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
        IcueTextField(
          controller: _remarks,
          label: 'Remarks (optional)',
          hintText: 'Notes regarding copy condition or history',
          maxLines: 3,
        ),
      ],
    );

    return IcueDialog(
      title: widget.title,
      size: IcueDialogSize.large,
      content: content,
      secondaryAction: IcueDialogAction(
        label: 'Cancel',
        variant: IcueButtonVariant.ghost,
        onPressed: _busy
            ? null
            : () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      primaryAction: IcueDialogAction(
        label: 'Save changes',
        icon: Icons.check_rounded,
        isLoading: _busy,
        onPressed: _busy ? null : _save,
      ),
    );
  }
}
