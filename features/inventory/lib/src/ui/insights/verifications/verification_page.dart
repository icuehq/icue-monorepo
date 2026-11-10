import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show VerificationReason;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One verification session: enter counts and reasons, submit, then approve / send back (FRS 10.21).
class VerificationPage extends StatefulWidget {
  const VerificationPage({required this.verification, super.key});

  final InventoryVerification verification;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late InventoryVerification _v = widget.verification;
  final _counts = <String, TextEditingController>{};
  final _reasons = <String, String?>{};
  var _busy = false;

  Future<void> _load() async {
    final insightsProvider = context.read<InsightsProvider>();
    final fresh = await insightsProvider.verification(_v.id);
    if (fresh != null) _v = fresh;
    await insightsProvider.loadLines(_v);
    if (!mounted) return;
    setState(() {
      for (final verificationLine in insightsProvider.lineItems) {
        _counts.putIfAbsent(
          verificationLine.balanceId,
          () =>
              TextEditingController(text: '${verificationLine.counted ?? ''}'),
        );
        _reasons[verificationLine.balanceId] = verificationLine.reason;
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
    for (final controller in _counts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  num? _counted(VerificationLine verificationLine) =>
      num.tryParse(_counts[verificationLine.balanceId]?.text.trim() ?? '');

  /// Calls [value]; reloads on success, else shows the error.
  Future<void> _act(
    String value,
    Map<String, Object?> data,
    String done,
  ) async {
    setState(() => _busy = true);
    final insightsProvider = context.read<InsightsProvider>();
    final result = await insightsProvider.act(value, {'id': _v.id, ...data});
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(
      context,
      result == null ? (insightsProvider.errorMessage ?? 'Failed') : done,
    );
    if (result != null) await _load();
  }

  /// Counts go straight to Firestore, so they are kept on the device while offline.
  /// True only when the server has them (submitting needs that).
  Future<bool> _save(List<VerificationLine> lineItems) async {
    setState(() => _busy = true);
    final insightsProvider = context.read<InsightsProvider>();
    final synced = await insightsProvider.saveCounts(_v, [
      for (final verificationLine in lineItems)
        if (_counted(verificationLine) case final c?)
          (verificationLine, c, _reasons[verificationLine.balanceId]),
    ]);
    if (!mounted) return false;
    setState(() => _busy = false);
    showMessage(
      context,
      insightsProvider.errorMessage ??
          (synced ? 'Counts saved' : 'Saved on this device; syncs when online'),
    );
    return synced;
  }

  /// A scanned item code adds one to the first line of that item that still needs it.
  void _scanned(String code, List<VerificationLine> lineItems) {
    final insightsProvider = context.read<InsightsProvider>();
    final hits = [
      for (final verificationLine in lineItems)
        if (insightsProvider.items[verificationLine.itemId]?.code
                .toLowerCase() ==
            code.toLowerCase())
          verificationLine,
    ];
    if (hits.isEmpty) return showMessage(context, 'No line for "$code"');
    final currentVerificationLine = hits.firstWhere(
      (verificationLine) => _counted(verificationLine) == null,
      orElse: () => hits.first,
    );
    setState(
      () => _counts[currentVerificationLine.balanceId]!.text =
          '${(_counted(currentVerificationLine) ?? 0) + 1}',
    );
    showMessage(
      context,
      '${insightsProvider.itemName(currentVerificationLine.itemId)}: ${_counted(currentVerificationLine)}',
    );
  }

  Future<void> _decide(String decision) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'approve'
              ? 'Apply adjustments?'
              : 'Send back for recount',
        ),
        content: IcueTextField(
          controller: controller,
          label: decision == 'approve' ? 'Comment (optional)' : 'Reason',
        ),
        actions: [
          IcueButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
            variant: IcueButtonVariant.ghost,
          ),
          IcueButton(
            label: 'Confirm',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _act('inventory-verification-decide', {
        'decision': decision,
        'comment': controller.text.trim(),
      }, 'Done');
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = context.watch<InsightsProvider>();
    final access = context.read<InventoryProvider>().access;
    final editable = _v.counting && access.can('inventory.stock.operate');
    return Scaffold(
      appBar: AppBar(title: Text(_v.number)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (editable) ...[
                Expanded(
                  child: IcueButton(
                    label: 'Save counts',
                    onPressed: _busy
                        ? null
                        : () => _save(insightsProvider.lineItems),
                    variant: IcueButtonVariant.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IcueButton(
                    label: 'Submit',
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _save(insightsProvider.lineItems) &&
                                mounted) {
                              await _act(
                                'inventory-verification-submit',
                                {},
                                'Submitted',
                              );
                            }
                          },
                  ),
                ),
              ],
              if (_v.submitted &&
                  access.can('inventory.adjustment.approve')) ...[
                Expanded(
                  child: IcueButton(
                    label: 'Send back',
                    onPressed: _busy ? null : () => _decide('reject'),
                    variant: IcueButtonVariant.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IcueButton(
                    label: 'Approve & apply',
                    onPressed: _busy ? null : () => _decide('approve'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: IcueCenteredBody(
        maxWidth: 900,
        child: insightsProvider.lineItems.isEmpty
            ? Center(
                child: insightsProvider.isLoading
                    ? const CircularProgressIndicator()
                    : Text(insightsProvider.errorMessage ?? 'No lines'),
              )
            : ListView(
                children: [
                  ListTile(
                    title: Text(
                      '${_v.storeName} · ${humanizeStatus(_v.status)}',
                    ),
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
                      child: IcueScanField(
                        hint: 'Scan item code to count',
                        clearOnScan: true,
                        onScan: (value) =>
                            _scanned(value, insightsProvider.lineItems),
                      ),
                    ),
                  for (final verificationLine in insightsProvider.lineItems)
                    _line(verificationLine, insightsProvider, editable),
                ],
              ),
      ),
    );
  }

  Widget _line(
    VerificationLine verificationLine,
    InsightsProvider insightsProvider,
    bool editable,
  ) {
    final counted = editable
        ? _counted(verificationLine)
        : verificationLine.counted;
    final difference = counted == null
        ? null
        : counted - verificationLine.expected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insightsProvider.itemName(verificationLine.itemId)),
                Text(
                  'Expected ${verificationLine.expected}${verificationLine.batchNumber == null ? '' : ' · batch ${verificationLine.batchNumber}'}'
                  '${difference == null || difference == 0 ? '' : ' · difference ${difference > 0 ? '+' : ''}$difference'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (editable && difference != null && difference != 0)
                  DropdownButton<String?>(
                    isDense: true,
                    value: _reasons[verificationLine.balanceId],
                    hint: const Text('Reason'),
                    items: [
                      for (final reason in VerificationReason.values)
                        DropdownMenuItem(
                          value: reason,
                          child: Text(humanizeStatus(reason)),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _reasons[verificationLine.balanceId] = value,
                    ),
                  )
                else if (verificationLine.reason != null)
                  Text(
                    humanizeStatus(verificationLine.reason!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: editable
                ? IcueTextField(
                    controller: _counts[verificationLine.balanceId],
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    label: 'Counted',
                  )
                : Text(
                    '${verificationLine.counted ?? '–'}',
                    textAlign: TextAlign.end,
                  ),
          ),
        ],
      ),
    );
  }
}
