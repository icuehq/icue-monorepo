import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Moves a maintenance request to [status]; completing records the repair cost, and parts drawn from a store.
class MaintenanceUpdateSheet extends StatefulWidget {
  const MaintenanceUpdateSheet({
    required this.job,
    required this.status,
    super.key,
  });

  final InventoryMaintenance job;
  final String status;

  @override
  State<MaintenanceUpdateSheet> createState() => _MaintenanceUpdateSheetState();
}

class _MaintenanceUpdateSheetState extends State<MaintenanceUpdateSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _technician = TextEditingController(text: widget.job.technician);
  late final _details = TextEditingController(text: widget.job.repairDetails);
  late final _cost = TextEditingController(text: widget.job.cost?.toString());
  late final _next = TextEditingController(text: widget.job.nextServiceDate);
  final _parts =
      <
        ({
          InventoryItem item,
          InventoryVariant? variant,
          String store,
          double quantity,
        })
      >[];
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
    for (final controller in [_technician, _details, _cost, _next]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addPart() async {
    final pick = await pickItem(context);
    if (pick == null || !mounted) return;
    final quantity = TextEditingController(text: '1');
    String? store;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(pick.item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreDropdown(
                value: store,
                onChanged: (value) => set(() => store = value),
              ),
              AppTextField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                label: 'Quantity (${pick.item.stockUnit})',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final currentQuantity = double.tryParse(quantity.text.trim());
    quantity.dispose();
    if (ok == true &&
        store != null &&
        currentQuantity != null &&
        currentQuantity > 0 &&
        mounted) {
      setState(
        () => _parts.add((
          item: pick.item,
          variant: pick.variant,
          store: store!,
          quantity: currentQuantity,
        )),
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    String? opt(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    await assetSubmit(
      context,
      (assetsProvider) =>
          assetsProvider.act('inventory-maintenance-setStatus', {
            'id': widget.job.id,
            'status': widget.status,
            'technician': opt(_technician),
            'repairDetails': opt(_details),
            'cost': double.tryParse(_cost.text.trim()),
            'nextServiceDate': opt(_next),
            'condition': _done ? _condition : null,
            'parts': [
              for (final part in _parts)
                {
                  'itemId': part.item.id,
                  'variantId': part.variant?.id,
                  'storeId': part.store,
                  'quantity': part.quantity,
                },
            ],
          }, requestId: _requestId),
      done: humanizeStatus(widget.status),
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
            '${widget.job.number} → ${humanizeStatus(widget.status)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!_cancel) ...[
            AppTextField(
              controller: _technician,
              validator: widget.status == 'assigned' ? requiredText : null,
              label: widget.status == 'assigned'
                  ? 'Technician / service provider *'
                  : 'Technician / service provider',
            ),
            AppTextField(
              controller: _details,
              maxLines: 2,
              label: 'Repair details',
            ),
            AppTextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _done
                  ? (value) => double.tryParse((value ?? '').trim()) == null
                        ? 'Enter the cost'
                        : null
                  : optionalNumber,
              label: _done ? 'Repair cost * (0 if none)' : 'Repair cost so far',
            ),
            if (_done) ...[
              labelled(
                'Condition after repair',
                AssetCondition.values,
                _condition,
                (value) => _condition = value,
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
            for (final part in _parts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${part.item.name} × ${part.quantity}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _parts.remove(part)),
                ),
              ),
            if (context.read<InventoryProvider>().access.can(
              'inventory.stock.operate',
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
            child: Text(_busy ? 'Saving…' : humanizeStatus(widget.status)),
          ),
        ],
      ),
    );
  }
}
