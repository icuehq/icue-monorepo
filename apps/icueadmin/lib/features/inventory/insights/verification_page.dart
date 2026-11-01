import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One verification session: enter counts and reasons, submit, then approve / send back (FRS 10.21).
class VerificationPage extends StatefulWidget {
  const VerificationPage({required this.verification, super.key});

  final InvVerification verification;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late InvVerification _v = widget.verification;
  final _counts = <String, TextEditingController>{};
  final _reasons = <String, String?>{};
  var _busy = false;

  Future<void> _load() async {
    final p = context.read<InsightsProvider>();
    final fresh = await p.verification(_v.id);
    if (fresh != null) _v = fresh;
    await p.loadLines(_v);
    if (!mounted) return;
    setState(() {
      for (final l in p.lines) {
        _counts.putIfAbsent(
          l.balanceId,
          () => TextEditingController(text: '${l.counted ?? ''}'),
        );
        _reasons[l.balanceId] = l.reason;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _counts.values) {
      c.dispose();
    }
    super.dispose();
  }

  num? _counted(VerificationLine l) =>
      num.tryParse(_counts[l.balanceId]?.text.trim() ?? '');

  /// Calls [fn]; reloads on success, else shows the error.
  Future<void> _act(String fn, Map<String, Object?> data, String done) async {
    setState(() => _busy = true);
    final p = context.read<InsightsProvider>();
    final res = await p.act(fn, {'id': _v.id, ...data});
    if (!mounted) return;
    setState(() => _busy = false);
    invSnack(context, res == null ? (p.errorMessage ?? 'Failed') : done);
    if (res != null) await _load();
  }

  /// Counts go straight to Firestore, so they are kept on the device while offline.
  /// True only when the server has them (submitting needs that).
  Future<bool> _save(List<VerificationLine> lines) async {
    setState(() => _busy = true);
    final p = context.read<InsightsProvider>();
    final synced = await p.saveCounts(_v, [
      for (final l in lines)
        if (_counted(l) case final c?) (l, c, _reasons[l.balanceId]),
    ]);
    if (!mounted) return false;
    setState(() => _busy = false);
    invSnack(
      context,
      p.errorMessage ??
          (synced ? 'Counts saved' : 'Saved on this device; syncs when online'),
    );
    return synced;
  }

  /// A scanned item code adds one to the first line of that item that still needs it.
  void _scanned(String code, List<VerificationLine> lines) {
    final p = context.read<InsightsProvider>();
    final hits = [
      for (final l in lines)
        if (p.items[l.itemId]?.code.toLowerCase() == code.toLowerCase()) l,
    ];
    if (hits.isEmpty) return invSnack(context, 'No line for "$code"');
    final l = hits.firstWhere(
      (l) => _counted(l) == null,
      orElse: () => hits.first,
    );
    setState(() => _counts[l.balanceId]!.text = '${(_counted(l) ?? 0) + 1}');
    invSnack(context, '${p.itemName(l.itemId)}: ${_counted(l)}');
  }

  Future<void> _decide(String decision) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          decision == 'approve'
              ? 'Apply adjustments?'
              : 'Send back for recount',
        ),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: decision == 'approve' ? 'Comment (optional)' : 'Reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _act('inv-verification-decide', {
        'decision': decision,
        'comment': c.text.trim(),
      }, 'Done');
    }
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsightsProvider>();
    final access = context.read<InventoryProvider>().access;
    final editable = _v.counting && access.can('inv.stock.operate');
    return Scaffold(
      appBar: AppBar(title: Text(_v.number)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (editable) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _save(p.lines),
                    child: const Text('Save counts'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _save(p.lines) && mounted) {
                              await _act(
                                'inv-verification-submit',
                                {},
                                'Submitted',
                              );
                            }
                          },
                    child: const Text('Submit'),
                  ),
                ),
              ],
              if (_v.submitted && access.can('inv.adjustment.approve')) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide('reject'),
                    child: const Text('Send back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _decide('approve'),
                    child: const Text('Approve & apply'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: p.lines.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'No lines'),
            )
          : ListView(
              children: [
                ListTile(
                  title: Text('${_v.storeName} · ${statusLabel(_v.status)}'),
                  subtitle: Text(
                    [
                      if (_v.remarks != null) _v.remarks!,
                      if (_v.approvalComment != null)
                        'Reviewer: ${_v.approvalComment}',
                    ].join('\n'),
                  ),
                ),
                if (editable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ScanField(
                      hint: 'Scan item code to count',
                      clearOnScan: true,
                      onScan: (c) => _scanned(c, p.lines),
                    ),
                  ),
                for (final l in p.lines) _line(l, p, editable),
              ],
            ),
    );
  }

  Widget _line(VerificationLine l, InsightsProvider p, bool editable) {
    final counted = editable ? _counted(l) : l.counted;
    final diff = counted == null ? null : counted - l.expected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.itemName(l.itemId)),
                Text(
                  'Expected ${l.expected}${l.batchNo == null ? '' : ' · batch ${l.batchNo}'}'
                  '${diff == null || diff == 0 ? '' : ' · diff ${diff > 0 ? '+' : ''}$diff'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (editable && diff != null && diff != 0)
                  DropdownButton<String?>(
                    isDense: true,
                    value: _reasons[l.balanceId],
                    hint: const Text('Reason'),
                    items: [
                      for (final r in VerificationLine.reasons)
                        DropdownMenuItem(value: r, child: Text(statusLabel(r))),
                    ],
                    onChanged: (v) => setState(() => _reasons[l.balanceId] = v),
                  )
                else if (l.reason != null)
                  Text(
                    statusLabel(l.reason!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: editable
                ? TextField(
                    controller: _counts[l.balanceId],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Counted'),
                    onChanged: (_) => setState(() {}),
                  )
                : Text('${l.counted ?? '–'}', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
