import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_line_card.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:inventory/src/ui/stock/shared/item_picker.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Create a purchase request for one store, or edit one ([existing]) before any goods arrive.
class PurchaseRequestFormPage extends StatefulWidget {
  const PurchaseRequestFormPage({super.key, this.existing});

  final InventoryPurchaseRequest? existing;

  @override
  State<PurchaseRequestFormPage> createState() =>
      _PurchaseRequestFormPageState();
}

class _PurchaseRequestFormPageState extends State<PurchaseRequestFormPage> {
  final _form = GlobalKey<FormState>();
  late final _purpose = TextEditingController(text: widget.existing?.purpose);
  late final _remarks = TextEditingController(text: widget.existing?.remarks);
  late final _date = TextEditingController(text: widget.existing?.requiredDate);
  final _lines = <RequestLineDraft>[];
  late String _priority = widget.existing?.priority ?? 'normal';
  late String? _store = widget.existing?.storeId;
  var _storeResets = 0;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
    final purchaseRequest = widget.existing;
    if (purchaseRequest != null) {
      final procurementProvider = context.read<ProcurementProvider>();
      for (final line in purchaseRequest.lineItems) {
        _lines.add(
          RequestLineDraft(
            line.itemId,
            procurementProvider.lineName(line),
            variantId: line.variantId,
            unit: procurementProvider.items[line.itemId]?.stockUnit ?? '',
            quantity: line.quantity.toQuantityText(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_purpose, _remarks, _date]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_store == null) return showMessage(context, 'Please select a store');
    if (_lines.isEmpty) {
      return showMessage(context, 'Please add at least one item');
    }
    final keys = {
      for (final line in _lines) '${line.itemId}|${line.variantId}',
    };
    if (keys.length != _lines.length) {
      return showMessage(context, 'Each item can only be added once');
    }
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act('inventory-purchaseRequest-save', {
            'id': ?widget.existing?.id,
            'storeId': _store,
            'requiredDate': _date.text,
            'priority': _priority,
            'purpose': _purpose.text.trim(),
            'remarks': _remarks.text.trim(),
            'lineItems': [
              for (final line in _lines)
                {
                  'itemId': line.itemId,
                  'variantId': line.variantId,
                  'quantity': double.parse(line.quantity.text.trim()),
                },
            ],
          }),
      done: widget.existing == null
          ? 'Purchase request created'
          : 'Purchase request updated',
    );
    if (mounted) setState(() => _busy = false);
  }

  /// Lines belong to one store's items, so a different store starts over.
  Future<void> _changeStore(String? value) async {
    if (value == _store) return;
    if (_lines.isNotEmpty) {
      final confirmed = await IcueDialog.confirm(
        context,
        title: 'Change store?',
        message: 'The items added so far belong to the current store and will be removed.',
        confirmLabel: 'Change store',
        destructive: true,
      );
      if (!confirmed || !mounted) {
        setState(() => _storeResets++);
        return;
      }
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
    }
    setState(() => _store = value);
  }

  Future<void> _addItem() async {
    if (_store == null) {
      return showMessage(context, 'Please select a store first');
    }
    final picked = await pickItem(context, assets: true, storeId: _store);
    if (picked == null || !mounted) return;
    final variant = picked.variant;
    final alreadyAdded = _lines.any(
      (line) => line.itemId == picked.item.id && line.variantId == variant?.id,
    );
    if (alreadyAdded) {
      return showMessage(context, 'This item is already in the list');
    }
    context.read<ProcurementProvider>().items[picked.item.id] = picked.item;
    final variantLabel = variant == null
        ? null
        : (variant.attrs.isEmpty
              ? variant.sku
              : variant.attrs.values.join(' · '));
    setState(() {
      _lines.add(
        RequestLineDraft(
          picked.item.id,
          variantLabel == null
              ? picked.item.name
              : '${picked.item.name} · $variantLabel',
          variantId: variant?.id,
          unit: picked.item.stockUnit,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = context.isWide;
    final isTabletOrWider = screenWidth >= IcueBreakpoints.table;
    final inventoryProvider = context.watch<InventoryProvider>();
    final visibleStores = inventoryProvider.stores
        .where((store) => store.active || store.id == _store)
        .length;
    final showStoreDropdown =
        !(inventoryProvider.restricted && visibleStores == 1);

    final storeField = StoreDropdown(
      // initialValue is read once; rebuild when a change is cancelled.
      key: ValueKey('$_store#$_storeResets'),
      value: _store,
      enabled: !editing,
      onChanged: _changeStore,
      prefixIcon: const Icon(Icons.warehouse_outlined),
    );

    final priorityField = IcueDropdown<String>(
      value: _priority,
      items: const [
        DropdownMenuItem(value: 'low', child: Text('Low')),
        DropdownMenuItem(value: 'normal', child: Text('Normal')),
        DropdownMenuItem(value: 'high', child: Text('High')),
        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
      ],
      onChanged: (value) => setState(() => _priority = value ?? 'normal'),
      label: 'Priority',
      icon: Icons.flag_outlined,
    );

    final storeAndPriorityCard = _SectionCard(
      icon: Icons.storefront_outlined,
      title: 'Store & Priority',
      child: showStoreDropdown && isTabletOrWider && !isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: storeField),
                const SizedBox(width: 12),
                Expanded(child: priorityField),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showStoreDropdown) ...[
                  storeField,
                  const SizedBox(height: 12),
                ],
                priorityField,
              ],
            ),
    );

    final requestDetailsCard = _SectionCard(
      icon: Icons.description_outlined,
      title: 'Request Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IcueTextField(
            controller: _purpose,
            validator: requiredText,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            label: 'Reason / Purpose *',
            hintText: 'e.g. Science lab supplies for next term',
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 12),
          IcueDateField(
            controller: _date,
            label: 'Needed by *',
            prefixIcon: const Icon(Icons.event_outlined),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
            initialDate: DateTime.now().add(const Duration(days: 7)),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          IcueTextField(
            controller: _remarks,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            label: 'Notes (optional)',
            hintText: 'Any extra instructions or supplier details',
            icon: Icons.notes_rounded,
          ),
        ],
      ),
    );

    final itemsCard = _SectionCard(
      icon: Icons.checklist_rounded,
      title: 'Items',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_lines.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_lines.length} ${_lines.length == 1 ? 'item' : 'items'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isTabletOrWider && _lines.isNotEmpty)
            IcueButton(
              label: 'Add item',
              onPressed: _addItem,
              variant: IcueButtonVariant.outline,
              size: IcueButtonSize.small,
              leadingIcon: Icons.add_rounded,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _store == null
                        ? 'Select a store first, then add items to buy.'
                        : 'No items added yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IcueButton(
                    label: 'Add item',
                    onPressed: _addItem,
                    variant: IcueButtonVariant.outline,
                    leadingIcon: Icons.add_rounded,
                  ),
                ],
              ),
            )
          else ...[
            for (final (index, line) in _lines.indexed) ...[
              RequestLineCard(
                line: line,
                onRemove: () =>
                    setState(() => _lines.removeAt(index).dispose()),
              ),
              if (index < _lines.length - 1) const SizedBox(height: 10),
            ],
            if (!isTabletOrWider) ...[
              const SizedBox(height: 12),
              IcueButton(
                label: 'Add item',
                onPressed: _addItem,
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.add_rounded,
              ),
            ],
          ],
        ],
      ),
    );

    final submitButton = IcueButton(
      label: _busy
          ? 'Saving…'
          : editing
          ? 'Save changes'
          : 'Create request',
      onPressed: _busy ? null : _save,
      leadingIcon: Icons.check_rounded,
      isLoading: _busy,
    );

    final footerButtons = isTabletOrWider
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IcueButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: IcueButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              submitButton,
            ],
          )
        : Row(children: [Expanded(child: submitButton)]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Edit ${widget.existing!.number}' : 'New Purchase Request',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        storeAndPriorityCard,
                        const SizedBox(height: 16),
                        requestDetailsCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: itemsCard),
                ],
              )
            else ...[
              storeAndPriorityCard,
              const SizedBox(height: 16),
              requestDetailsCard,
              const SizedBox(height: 16),
              itemsCard,
            ],
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 16,
              vertical: 12,
            ),
            child: footerButtons,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
