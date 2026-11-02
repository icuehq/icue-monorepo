import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:icueadmin/features/inventory/procurement/procurement_ui.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Draft a PO against an approved request, from a [quotation] (vendor and prices fixed) or directly.
/// With [existing], edits that draft.
class PurchaseOrderFormPage extends StatefulWidget {
  const PurchaseOrderFormPage({
    required this.request,
    this.quotation,
    this.existing,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final InventoryQuotation? quotation;
  final InventoryPurchaseOrder? existing;

  @override
  State<PurchaseOrderFormPage> createState() => _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState extends State<PurchaseOrderFormPage> {
  final _form = GlobalKey<FormState>();
  late final _expected = TextEditingController(
    text: widget.existing?.expectedDate,
  );
  late final _terms = TextEditingController(text: widget.existing?.terms);
  late final _remarks = TextEditingController(text: widget.existing?.remarks);
  late final _discount = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.discount),
  );
  late final _tax = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.tax),
  );
  late final _delivery = TextEditingController(
    text: widget.existing == null ? '' : money(widget.existing!.delivery),
  );
  final _lines = <OrderLineInput>[];
  late String? _vendor =
      widget.existing?.vendorId ?? widget.quotation?.vendorId;
  late int _campus =
      widget.existing?.deliveryCampusId ?? widget.request.campusId;
  var _busy = false;

  String? get _quotationId =>
      widget.existing?.quotationId ?? widget.quotation?.id;

  @override
  void initState() {
    super.initState();
    final procurementProvider = context.read<ProcurementProvider>();
    if (procurementProvider.vendors.isEmpty) procurementProvider.loadVendors();
    final locked = _quotationId != null;

    OrderLineInput add(
      String item,
      String? variant,
      double quantity,
      double price,
    ) => OrderLineInput(
      item,
      variant,
      procurementProvider.itemName(item),
      quantity: formatQuantity(quantity),
      price: price == 0 ? '' : formatQuantity(price),
      priceLocked: locked,
    );

    final purchaseOrder = widget.existing;
    final quote = widget.quotation;
    if (purchaseOrder != null) {
      for (final orderLine in purchaseOrder.lineItems) {
        _lines.add(
          add(
            orderLine.itemId,
            orderLine.variantId,
            orderLine.quantity,
            orderLine.unitPrice,
          ),
        );
      }
    } else if (quote != null) {
      for (final orderLine in quote.lineItems) {
        final left = widget.request.lineItems
            .where(
              (purchaseRequestLine) =>
                  purchaseRequestLine.itemId == orderLine.itemId,
            )
            .map(
              (purchaseRequestLine) =>
                  purchaseRequestLine.quantity -
                  purchaseRequestLine.quantityOrdered,
            );
        final quantity = left.isEmpty || left.first > orderLine.quantity
            ? orderLine.quantity
            : left.first;
        if (quantity > 0) {
          _lines.add(
            add(
              orderLine.itemId,
              orderLine.variantId,
              quantity,
              orderLine.unitPrice,
            ),
          );
        }
      }
    } else {
      for (final purchaseRequestLine in widget.request.lineItems) {
        if (purchaseRequestLine.quantity >
            purchaseRequestLine.quantityOrdered) {
          _lines.add(
            add(
              purchaseRequestLine.itemId,
              purchaseRequestLine.variantId,
              purchaseRequestLine.quantity -
                  purchaseRequestLine.quantityOrdered,
              purchaseRequestLine.estimatedPrice,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _expected,
      _terms,
      _remarks,
      _discount,
      _tax,
      _delivery,
    ]) {
      controller.dispose();
    }
    for (final orderLineInput in _lines) {
      orderLineInput.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save({required bool issue}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Nothing left to order');
    setState(() => _busy = true);
    await procSubmit(context, (procurementProvider) async {
      final saved = await procurementProvider.act(
        'inventory-purchaseOrder-save',
        {
          'id': ?widget.existing?.id,
          'purchaseRequestId': widget.request.id,
          'quotationId': ?_quotationId,
          'vendorId': _vendor,
          'deliveryCampusId': _campus,
          'expectedDate': _expected.text,
          'terms': _terms.text.trim(),
          'remarks': _remarks.text.trim(),
          'lineItems': [
            for (final orderLineInput in _lines)
              orderLineInput.toJson('quantityOrdered'),
          ],
          'discount': _v(_discount),
          'tax': _v(_tax),
          'delivery': _v(_delivery),
        },
      );
      if (saved == null || !issue) return saved;
      return procurementProvider.act('inventory-purchaseOrder-issue', {
        'id': saved['id'],
      });
    }, done: issue ? 'PO saved and issued' : 'PO draft saved');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = context.read<InventoryProvider>().access;
    final campuses = {...access.campusIds, _campus}.toList();
    final vendors = context.watch<ProcurementProvider>().vendors.where(
      (vendor) => vendor.active || vendor.id == _vendor,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing?.number ?? 'PO · ${widget.request.number}'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vendor & Destination Campus Card
            Card(
              elevation: 0,
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
                        Icon(
                          Icons.business_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Supplier & Campus',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _vendor,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / Vendor *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: [
                        for (final vendor in vendors)
                          DropdownMenuItem(
                            value: vendor.id,
                            child: Text(vendor.name),
                          ),
                      ],
                      onChanged: _quotationId == null
                          ? (value) => setState(() => _vendor = value)
                          : null,
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _campus,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Campus *',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        for (final value in campuses)
                          DropdownMenuItem(
                            value: value,
                            child: Text('Campus $value'),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _campus = value ?? _campus),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Date & Terms Card
            Card(
              elevation: 0,
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
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delivery Terms',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    dateField(
                      context,
                      _expected,
                      'Expected Delivery Date *',
                      first: DateTime.now(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _terms,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Terms and conditions',
                        hintText: 'e.g. 100% on delivery, 30 days warranty',
                        prefixIcon: Icon(Icons.gavel_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarks,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Dispatch Notes',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Line Items Card
            Card(
              elevation: 0,
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ordered Items',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_lines.length} lines',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final (n, l) in _lines.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderLineCard(
                          line: l,
                          onChanged: () => setState(() {}),
                          onRemove: _lines.length > 1
                              ? () =>
                                    setState(() => _lines.removeAt(n).dispose())
                              : null,
                        ),
                      ),
                    const Divider(height: 16),
                    OrderTotals(
                      lineItems: _lines,
                      discount: _discount,
                      tax: _tax,
                      delivery: _delivery,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(issue: true),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Saving…' : 'Save and Issue PO'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(issue: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save Draft PO'),
            ),
          ],
        ),
      ),
    );
  }
}
