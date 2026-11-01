import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';

/// Reports a fault on [asset], or edits a live request [job] (FRS 10.20).
class MaintenanceFormSheet extends StatefulWidget {
  const MaintenanceFormSheet({this.asset, this.job, super.key})
    : assert(asset != null || job != null);

  final InvAsset? asset;
  final InvMaintenance? job;

  @override
  State<MaintenanceFormSheet> createState() => _MaintenanceFormSheetState();
}

class _MaintenanceFormSheetState extends State<MaintenanceFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _issue = TextEditingController(text: widget.job?.issue);
  late final _tech = TextEditingController(text: widget.job?.technician);
  late final _next = TextEditingController(text: widget.job?.nextServiceDate);
  late var _priority = widget.job?.priority ?? 'medium';
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_issue, _tech, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await assetSubmit(
      context,
      (p) => p.act('inv-maintenance-save', {
        'id': widget.job?.id,
        'assetId': widget.job?.assetId ?? widget.asset!.id,
        'issue': _issue.text.trim(),
        'priority': _priority,
        'technician': opt(_tech),
        'nextServiceDate': opt(_next),
      }, requestId: _requestId),
      done: widget.job == null ? 'Fault reported' : 'Updated',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.job == null ? 'Report fault' : widget.job!.number,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(widget.asset?.assetId ?? widget.job!.assetCode),
          TextFormField(
            controller: _issue,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Issue *'),
            validator: requiredText,
          ),
          labelled(
            'Priority',
            InvMaintenance.priorities,
            _priority,
            (v) => setState(() => _priority = v!),
          ),
          TextFormField(
            controller: _tech,
            decoration: const InputDecoration(
              labelText: 'Technician / service provider',
            ),
          ),
          optionalDate(
            context,
            _next,
            'Next service date',
            first: now,
            last: now.add(const Duration(days: 1095)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
