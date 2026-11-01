import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Moves a maintenance request to [status]; completing records the repair cost, and parts drawn from a store.
class MaintenanceUpdateSheet extends StatefulWidget {
  const MaintenanceUpdateSheet({
    required this.job,
    required this.status,
    super.key,
  });

  final InvMaintenance job;
  final String status;

  @override
  State<MaintenanceUpdateSheet> createState() => _MaintenanceUpdateSheetState();
}

class _MaintenanceUpdateSheetState extends State<MaintenanceUpdateSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _tech = TextEditingController(text: widget.job.technician);
  late final _details = TextEditingController(text: widget.job.repairDetails);
  late final _cost = TextEditingController(text: widget.job.cost?.toString());
  late final _next = TextEditingController(text: widget.job.nextServiceDate);
  final _parts =
      <({InvItem item, InvVariant? variant, String store, double qty})>[];
  String? _condition;
  var _busy = false;

  bool get _done => widget.status == 'completed';
  bool get _cancel => widget.status == 'cancelled';

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    for (final c in [_tech, _details, _cost, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPart() async {
    final pick = await pickItem(context);
    if (pick == null || !mounted) return;
    final qty = TextEditingController(text: '1');
    String? store;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(pick.item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreDropdown(
                value: store,
                onChanged: (v) => set(() => store = v),
              ),
              TextField(
                controller: qty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity (${pick.item.stockUnit})',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final q = double.tryParse(qty.text.trim());
    qty.dispose();
    if (ok == true && store != null && q != null && q > 0 && mounted) {
      setState(
        () => _parts.add((
          item: pick.item,
          variant: pick.variant,
          store: store!,
          qty: q,
        )),
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await assetSubmit(
      context,
      (p) => p.act('inv-maintenance-setStatus', {
        'id': widget.job.id,
        'status': widget.status,
        'technician': opt(_tech),
        'repairDetails': opt(_details),
        'cost': double.tryParse(_cost.text.trim()),
        'nextServiceDate': opt(_next),
        'condition': _done ? _condition : null,
        'parts': [
          for (final x in _parts)
            {
              'itemId': x.item.id,
              'variantId': x.variant?.id,
              'storeId': x.store,
              'qty': x.qty,
            },
        ],
      }, requestId: _requestId),
      done: statusLabel(widget.status),
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
            '${widget.job.number} → ${statusLabel(widget.status)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!_cancel) ...[
            TextFormField(
              controller: _tech,
              decoration: InputDecoration(
                labelText: widget.status == 'assigned'
                    ? 'Technician / service provider *'
                    : 'Technician / service provider',
              ),
              validator: widget.status == 'assigned' ? requiredText : null,
            ),
            TextFormField(
              controller: _details,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Repair details'),
            ),
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _done
                    ? 'Repair cost * (0 if none)'
                    : 'Repair cost so far',
              ),
              validator: _done
                  ? (v) => double.tryParse((v ?? '').trim()) == null
                        ? 'Enter the cost'
                        : null
                  : optionalNumber,
            ),
            if (_done) ...[
              labelled(
                'Condition after repair',
                InvAsset.conditions,
                _condition,
                (v) => _condition = v,
              ),
              optionalDate(
                context,
                _next,
                'Next service date',
                first: now,
                last: now.add(const Duration(days: 1095)),
              ),
            ],
            const SizedBox(height: 8),
            Text('Parts used', style: Theme.of(context).textTheme.titleSmall),
            for (final x in _parts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${x.item.name} × ${x.qty}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _parts.remove(x)),
                ),
              ),
            if (context.read<InventoryProvider>().access.can(
              'inv.stock.operate',
            ))
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add part from store'),
                onPressed: _addPart,
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : statusLabel(widget.status)),
          ),
        ],
      ),
    );
  }
}
