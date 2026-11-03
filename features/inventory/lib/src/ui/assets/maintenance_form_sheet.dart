import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/asset_ui.dart';

/// Reports a fault on [asset], or edits a live request [job] (FRS 10.20).
class MaintenanceFormSheet extends StatefulWidget {
  const MaintenanceFormSheet({this.asset, this.job, super.key})
    : assert(asset != null || job != null);

  final InventoryAsset? asset;
  final InventoryMaintenance? job;

  @override
  State<MaintenanceFormSheet> createState() => _MaintenanceFormSheetState();
}

class _MaintenanceFormSheetState extends State<MaintenanceFormSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _issue = TextEditingController(text: widget.job?.issue);
  late final _technician = TextEditingController(text: widget.job?.technician);
  late final _next = TextEditingController(text: widget.job?.nextServiceDate);
  late var _priority = widget.job?.priority ?? 'medium';
  var _busy = false;

  @override
  void dispose() {
    for (final controller in [_issue, _technician, _next]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    String? opt(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    await assetSubmit(
      context,
      (assetsProvider) => assetsProvider.act('inventory-maintenance-save', {
        'id': widget.job?.id,
        'assetId': widget.job?.assetId ?? widget.asset!.id,
        'issue': _issue.text.trim(),
        'priority': _priority,
        'technician': opt(_technician),
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
            InventoryMaintenance.priorities,
            _priority,
            (value) => setState(() => _priority = value!),
          ),
          TextFormField(
            controller: _technician,
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
