import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/asset_ui.dart';

enum AssetAction {
  assign('Assign', 'inventory-asset-assign'),
  transfer('Transfer', 'inventory-asset-transfer'),
  giveBack('Return', 'inventory-asset-return'),
  condition('Update condition', 'inventory-asset-setCondition'),
  retire('Retire / dispose', 'inventory-asset-retire');

  const AssetAction(this.title, this.value);

  final String title;
  final String value;
}

/// One form for the custody and lifecycle actions of an asset (FRS 10.19).
class AssetActionSheet extends StatefulWidget {
  const AssetActionSheet({
    required this.asset,
    required this.action,
    super.key,
  });

  final InventoryAsset asset;
  final AssetAction action;

  @override
  State<AssetActionSheet> createState() => _AssetActionSheetState();
}

class _AssetActionSheetState extends State<AssetActionSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _erpId = TextEditingController();
  final _location = TextEditingController();
  final _expected = TextEditingController();
  final _text = TextEditingController();
  var _type = 'staff';
  late var _condition = widget.asset.condition;
  String? _status;
  var _kind = 'retired';
  var _ack = false;
  var _busy = false;

  AssetAction get _a => widget.action;
  bool get _custody => _a == AssetAction.assign || _a == AssetAction.transfer;

  @override
  void dispose() {
    for (final controller in [_erpId, _location, _expected, _text]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _body() {
    String? opt(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return {
      'id': widget.asset.id,
      if (_custody) ...{
        'assignee': {
          'type': _type,
          'personErpId': int.parse(_erpId.text.trim()),
        },
        'expectedReturn': opt(_expected),
        'acknowledged': _ack,
      },
      if (_a != AssetAction.retire) 'condition': _condition,
      if (_a != AssetAction.condition && _a != AssetAction.retire)
        'location': opt(_location),
      if (_a == AssetAction.giveBack || _a == AssetAction.condition)
        'remarks': opt(_text),
      if (_a == AssetAction.condition) 'status': _status,
      if (_a == AssetAction.retire) ...{
        'status': _kind,
        'reason': _text.text.trim(),
      },
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await assetSubmit(
      context,
      (assetsProvider) =>
          assetsProvider.act(_a.value, _body(), requestId: _requestId),
      done: '${_a.title} done',
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
            '${_a.title} · ${widget.asset.assetId}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_custody) ...[
            labelled(
              'Custodian type',
              const ['staff', 'student', 'department'],
              _type,
              (value) => setState(() => _type = value!),
            ),
            TextFormField(
              controller: _erpId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ERP ID *'),
              validator: (value) => int.tryParse((value ?? '').trim()) == null
                  ? 'Enter a number'
                  : null,
            ),
            optionalDate(
              context,
              _expected,
              'Expected return',
              first: now,
              last: now.add(const Duration(days: 1095)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custodian acknowledged receipt'),
              value: _ack,
              onChanged: (value) => setState(() => _ack = value),
            ),
          ],
          if (_a != AssetAction.retire)
            labelled(
              _a == AssetAction.assign || _a == AssetAction.transfer
                  ? 'Condition at handover'
                  : _a == AssetAction.giveBack
                  ? 'Condition at return'
                  : 'Condition',
              InventoryAsset.conditions,
              _condition,
              (value) => setState(() => _condition = value!),
            ),
          if (_a != AssetAction.condition && _a != AssetAction.retire)
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          if (_a == AssetAction.condition)
            labelled(
              'Mark as',
              const ['available', 'damaged', 'lost'],
              _status,
              (value) => setState(() => _status = value),
            ),
          if (_a == AssetAction.retire)
            labelled(
              'Outcome',
              const ['retired', 'disposed'],
              _kind,
              (value) => setState(() => _kind = value!),
            ),
          if (_a == AssetAction.giveBack ||
              _a == AssetAction.condition ||
              _a == AssetAction.retire)
            TextFormField(
              controller: _text,
              decoration: InputDecoration(
                labelText: _a == AssetAction.retire ? 'Reason *' : 'Remarks',
              ),
              validator: _a == AssetAction.retire ? requiredText : null,
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : _a.title),
          ),
        ],
      ),
    );
  }
}
