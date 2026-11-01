import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One verification session: scan, submit, then review and approve corrections.
class VerificationSheet extends StatefulWidget {
  const VerificationSheet({super.key, required this.id});

  final String id;

  static Future<void> show(BuildContext context, String id) =>
      showFormSheet(context, () => VerificationSheet(id: id));

  @override
  State<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<VerificationSheet> {
  LibraryVerification? _v;
  final Set<String> _lost = {};
  final Set<String> _move = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final verification = await context.read<LibraryProvider>().verification(
      widget.id,
    );
    if (mounted) setState(() => _v = verification);
  }

  Future<void> _scan(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final ok = await libraryProvider.scanVerification(widget.id, [code.trim()]);
    if (!mounted) return;
    if (ok) {
      await _refresh();
    } else {
      showMessage(context, libraryProvider.errorMessage ?? 'Scan failed');
    }
  }

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
    final verification = _v;
    if (verification == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final access = context.watch<LibraryProvider>().access;
    final review = verification.isSubmitted && access.can('library.settings');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${verification.number} · ${verification.libraryName}',
              style: theme.textTheme.titleMedium,
            ),
            Chip(label: Text(verificationStatusLabel(verification.status))),
          ],
        ),
        Text(
          '${verification.scanned.length} scanned of ${verification.expected.length} expected'
          '${verification.onLoanCopyIds.isEmpty ? '' : ' · ${verification.onLoanCopyIds.length} on loan (not counted)'}',
        ),
        if (verification.isCounting &&
            access.can('library.catalogue.manage')) ...[
          const SizedBox(height: 12),
          ScanField(
            hint: 'Scan barcode or enter accession no.',
            clearOnScan: true,
            autofocus: true,
            onScan: _scan,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (libraryProvider) =>
                        libraryProvider.submitVerification(verification.id),
                  ),
            child: Text(
              'Submit count (${verification.notYetScanned.length} not scanned)',
            ),
          ),
        ],
        if (!verification.isCounting) ...[
          const Divider(height: 24),
          Text(
            'Missing (${verification.missing.length})',
            style: theme.textTheme.titleSmall,
          ),
          for (final copyId in verification.missing)
            review
                ? CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(copyId),
                    subtitle: const Text('Mark as lost'),
                    value: _lost.contains(copyId),
                    onChanged: (checked) => setState(
                      () => checked! ? _lost.add(copyId) : _lost.remove(copyId),
                    ),
                  )
                : Text(copyId),
          const SizedBox(height: 8),
          Text(
            'Unexpected (${verification.unexpected.length})',
            style: theme.textTheme.titleSmall,
          ),
          for (final copyId in verification.unexpected)
            review
                ? CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(copyId),
                    subtitle: const Text('Move into this library'),
                    value: _move.contains(copyId),
                    onChanged: (checked) => setState(
                      () => checked! ? _move.add(copyId) : _move.remove(copyId),
                    ),
                  )
                : Text(copyId),
          if (verification.investigate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Under investigation: ${verification.investigate.join(', ')}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
        if (review) ...[
          const SizedBox(height: 12),
          Text(
            'Missing copies left unticked stay recorded for investigation.',
            style: theme.textTheme.bodySmall,
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (libraryProvider) => libraryProvider.approveVerification({
                      'id': verification.id,
                      'lost': _lost.toList(),
                      'move': _move.toList(),
                    }),
                  ),
            child: const Text('Approve corrections'),
          ),
        ],
      ],
    );
  }
}
