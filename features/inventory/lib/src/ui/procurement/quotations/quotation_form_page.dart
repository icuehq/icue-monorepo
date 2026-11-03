import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:provider/provider.dart';

/// Add a quotation to an approved request, or edit a draft ([existing]).
class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({required this.request, this.existing, super.key});

  final InventoryPurchaseRequest request;
  final InventoryQuotation? existing;

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  final _form = GlobalKey<FormState>();
  late final _ref = TextEditingController(text: widget.existing?.vendorRef);
  late final _valid = TextEditingController(text: widget.existing?.validUntil);
  late final _days = TextEditingController(
    text: widget.existing?.deliveryDays?.toString(),
  );
  late final _remarks = TextEditingController(text: widget.existing?.remarks);
  late final _discount = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.discount.toAmountText(),
  );
  late final _tax = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.tax.toAmountText(),
  );
  late final _delivery = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.delivery.toAmountText(),
  );
  final _lines = <OrderLineInput>[];
  late String? _vendor = widget.existing?.vendorId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final procurementProvider = context.read<ProcurementProvider>();
    if (procurementProvider.vendors.isEmpty) procurementProvider.loadVendors();
    final quotation = widget.existing;
    if (quotation != null) {
      for (final orderLine in quotation.lineItems) {
        _lines.add(
          OrderLineInput(
            orderLine.itemId,
            orderLine.variantId,
            procurementProvider.itemName(orderLine.itemId),
            quantity: orderLine.quantity.toQuantityText(),
            price: orderLine.unitPrice.toQuantityText(),
          ),
        );
      }
    } else {
      for (final purchaseRequestLine in widget.request.lineItems) {
        _lines.add(
          OrderLineInput(
            purchaseRequestLine.itemId,
            purchaseRequestLine.variantId,
            procurementProvider.itemName(purchaseRequestLine.itemId),
            quantity: purchaseRequestLine.quantity.toQuantityText(),
            price: purchaseRequestLine.estimatedPrice > 0
                ? purchaseRequestLine.estimatedPrice.toQuantityText()
                : '',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _ref,
      _valid,
      _days,
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

  Future<void> _save({required bool finalize}) async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Keep at least one item');
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act('inventory-quotation-save', {
            'id': ?widget.existing?.id,
            'purchaseRequestId': widget.request.id,
            'vendorId': _vendor,
            'vendorRef': _ref.text.trim(),
            'validUntil': _valid.text,
            'deliveryDays': int.tryParse(_days.text.trim()),
            'lineItems': [
              for (final orderLineInput in _lines)
                orderLineInput.toJson('quantity'),
            ],
            'discount': _v(_discount),
            'tax': _v(_tax),
            'delivery': _v(_delivery),
            'remarks': _remarks.text.trim(),
            'final': finalize,
          }),
      done: finalize ? 'Quotation recorded' : 'Draft saved',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendors = context.watch<ProcurementProvider>().vendors.where(
      (vendor) => vendor.active || vendor.id == _vendor,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing?.number ?? 'Quotation · ${widget.request.number}',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vendor & Reference Card
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
                          'Supplier Details',
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
                        labelText: 'Select Vendor *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: [
                        for (final vendor in vendors)
                          DropdownMenuItem(
                            value: vendor.id,
                            child: Text(vendor.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _vendor = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ref,
                      decoration: const InputDecoration(
                        labelText: "Vendor's quotation no. / reference",
                        hintText: 'e.g. QT-2024-8849',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Validity & Lead Time Card
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
                          Icons.schedule_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Validity & Delivery Lead Time',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: dateField(
                            context,
                            _valid,
                            'Valid Until *',
                            first: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _days,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Lead time (days)',
                              hintText: 'e.g. 7',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarks,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Notes',
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
                          Icons.receipt_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quoted Prices',
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
                            '${_lines.length} items',
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
              onPressed: _busy ? null : () => _save(finalize: true),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_busy ? 'Saving…' : 'Record Quotation'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : () => _save(finalize: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save Draft Quotation'),
            ),
          ],
        ),
      ),
    );
  }
}
