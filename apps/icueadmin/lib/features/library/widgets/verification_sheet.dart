import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One verification session: scan, submit, then review and approve corrections.
class VerificationSheet extends StatefulWidget {
  const VerificationSheet({super.key, required this.id});

  final String id;

  static Future<void> show(BuildContext context, String id) =>
      showInvSheet(context, () => VerificationSheet(id: id));

  @override
  State<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<VerificationSheet> {
  LibVerification? _v;
  final Set<String> _lost = {};
  final Set<String> _move = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final v = await context.read<LibraryProvider>().verification(widget.id);
    if (mounted) setState(() => _v = v);
  }

  Future<void> _scan(String code) async {
    final p = context.read<LibraryProvider>();
    final ok = await p.scanVerification(widget.id, [code.trim()]);
    if (!mounted) return;
    if (ok) {
      await _refresh();
    } else {
      invSnack(context, p.errorMessage ?? 'Scan failed');
    }
  }

  Future<void> _run(Future<bool> Function(LibraryProvider p) action) async {
    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    await libSubmit(context, () => action(p));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (v == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final access = context.watch<LibraryProvider>().access;
    final review = v.isSubmitted && access.can('lib.settings');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${v.number} · ${v.libraryName}',
              style: theme.textTheme.titleMedium,
            ),
            Chip(label: Text(verificationStatusLabel(v.status))),
          ],
        ),
        Text(
          '${v.scanned.length} scanned of ${v.expected.length} expected'
          '${v.onLoan.isEmpty ? '' : ' · ${v.onLoan.length} on loan (not counted)'}',
        ),
        if (v.isCounting && access.can('lib.catalogue.manage')) ...[
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
                : () => _run((p) => p.submitVerification(v.id)),
            child: Text('Submit count (${v.notYetScanned.length} not scanned)'),
          ),
        ],
        if (!v.isCounting) ...[
          const Divider(height: 24),
          Text(
            'Missing (${v.missing.length})',
            style: theme.textTheme.titleSmall,
          ),
          for (final c in v.missing)
            review
                ? CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c),
                    subtitle: const Text('Mark as lost'),
                    value: _lost.contains(c),
                    onChanged: (x) =>
                        setState(() => x! ? _lost.add(c) : _lost.remove(c)),
                  )
                : Text(c),
          const SizedBox(height: 8),
          Text(
            'Unexpected (${v.unexpected.length})',
            style: theme.textTheme.titleSmall,
          ),
          for (final c in v.unexpected)
            review
                ? CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c),
                    subtitle: const Text('Move into this library'),
                    value: _move.contains(c),
                    onChanged: (x) =>
                        setState(() => x! ? _move.add(c) : _move.remove(c)),
                  )
                : Text(c),
          if (v.investigate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Under investigation: ${v.investigate.join(', ')}',
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
                    (p) => p.approveVerification({
                      'id': v.id,
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
