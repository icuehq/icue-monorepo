import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_validators.dart';
import 'package:provider/provider.dart';

/// Records goods that arrived against a purchase request: good units go into the store's stock at the
/// item's default price
/// (asset units as unregistered assets), damaged units into its damaged stock. Pops `true` when saved.
class PurchaseReceivePage extends StatefulWidget {
  const PurchaseReceivePage({required this.request, super.key});

  final InventoryPurchaseRequest request;

  @override
  State<PurchaseReceivePage> createState() => _PurchaseReceivePageState();
}

class _ArrivalDraft {
  _ArrivalDraft(this.line, this.item);

  final PurchaseRequestLine line;
  final InventoryItem? item;
  final received = TextEditingController();
  final damaged = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();

  bool get isAsset => item?.tracking == Tracking.asset;
  double get good => double.tryParse(received.text.trim()) ?? 0;
  double get broken => double.tryParse(damaged.text.trim()) ?? 0;

  void dispose() {
    for (final controller in [received, damaged, batchNumber, expiry]) {
      controller.dispose();
    }
  }
}

class _PurchaseReceivePageState extends State<PurchaseReceivePage> {
  final _form = GlobalKey<FormState>();
  late final List<_ArrivalDraft> _drafts;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final items = context.read<ProcurementProvider>().items;
    _drafts = [
      for (final line in widget.request.lineItems)
        if (line.pending > 0) _ArrivalDraft(line, items[line.itemId]),
    ];
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final arrived = [
      for (final draft in _drafts)
        if (draft.good + draft.broken > 0) draft,
    ];
    if (arrived.isEmpty) return showMessage(context, 'Enter what was received');
    setState(() => _busy = true);
    final procurementProvider = context.read<ProcurementProvider>();
    final stockLines = arrived.where((draft) => !draft.isAsset).toList();
    if (stockLines.isNotEmpty) {
      final result = await procurementProvider.act(
        'inventory-purchaseRequest-receive',
        {
          'id': widget.request.id,
          'lineItems': [
            for (final draft in stockLines)
              {
                'itemId': draft.line.itemId,
                'variantId': draft.line.variantId,
                'received': draft.good,
                'damaged': draft.broken,
                if (draft.item?.tracking == Tracking.batch) ...{
                  'batchNumber': draft.batchNumber.text.trim(),
                  'expiryDate': draft.expiry.text.trim().isEmpty
                      ? null
                      : draft.expiry.text.trim(),
                },
              },
          ],
        },
      );
      if (result == null) return _fail(procurementProvider.errorMessage);
    }
    // Each asset line is its own callable: it adds the units and updates the request together.
    for (final draft in arrived.where((draft) => draft.isAsset)) {
      final result = await procurementProvider.act('inventory-asset-receive', {
        'itemId': draft.line.itemId,
        'storeId': widget.request.storeId,
        'quantity': draft.good.toInt(),
        'damaged': draft.broken.toInt(),
        'purchaseRequestId': widget.request.id,
      }, requestId: newRequestId());
      if (result == null) return _fail(procurementProvider.errorMessage);
    }
    if (!mounted) return;
    showMessage(
      context,
      arrived.any((draft) => draft.isAsset && draft.good > 0)
          ? 'Goods received. Register the new assets in Asset management.'
          : 'Goods received',
    );
    Navigator.of(context).pop(true);
  }

  /// Lines saved before a failure stay saved; the request page reloads and shows them.
  void _fail(String? message) {
    if (!mounted) return;
    setState(() => _busy = false);
    IcueToast.error(context, message ?? 'Could not record the receipt');
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    // pushFormPage supplies the dialog / page and the scroll view: this is only the form body.
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Receive · ${widget.request.number}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_drafts.isEmpty)
            const Text('Everything on this request has been received.'),
          for (final draft in _drafts)
            _ArrivalCard(
              draft: draft,
              name: procurementProvider.lineName(draft.line),
            ),
          const SizedBox(height: 8),
          IcueButton(
            label: _busy ? 'Saving…' : 'Confirm receipt',
            onPressed: _busy || _drafts.isEmpty ? null : _save,
            leadingIcon: Icons.check_circle_outline_rounded,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({required this.draft, required this.name});

  final _ArrivalDraft draft;
  final String name;

  /// Empty or a non-negative number (whole for assets), with good + damaged within what is pending.
  String? _validate(String? text) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null || number < 0) return 'Enter a valid number';
    if (draft.good + draft.broken > draft.line.pending) {
      return 'Only ${draft.line.pending.toQuantityText()} pending';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = draft.item?.stockUnit ?? '';
    final formatters = draft.isAsset
        ? [FilteringTextInputFormatter.digitsOnly]
        : quantityFormatters;
    const keyboard = TextInputType.numberWithOptions(decimal: true);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Requested ${draft.line.quantity.toQuantityText()} · '
              'pending ${draft.line.pending.toQuantityText()}'
              '${unit.isEmpty ? '' : ' $unit'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IcueTextField(
                    controller: draft.received,
                    keyboardType: keyboard,
                    inputFormatters: formatters,
                    validator: _validate,
                    label: 'Received in good condition',
                    hintText: '0',
                    suffixText: unit.isEmpty ? null : unit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IcueTextField(
                    controller: draft.damaged,
                    keyboardType: keyboard,
                    inputFormatters: formatters,
                    validator: _validate,
                    label: 'Damaged',
                    hintText: '0',
                    suffixText: unit.isEmpty ? null : unit,
                  ),
                ),
              ],
            ),
            if (draft.isAsset)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Each good unit is added as an unregistered asset. Damaged '
                  'units are only recorded on the request.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (draft.item?.tracking == Tracking.batch) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: IcueTextField(
                      controller: draft.batchNumber,
                      maxLength: 50,
                      // Only needed when something arrives.
                      validator: (value) => draft.good + draft.broken > 0
                          ? validateRequiredText(value)
                          : null,
                      label: 'Batch number',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IcueDateField(
                      controller: draft.expiry,
                      label: 'Expiry date',
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
