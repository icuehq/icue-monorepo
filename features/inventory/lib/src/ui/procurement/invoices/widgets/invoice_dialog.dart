import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:provider/provider.dart';

/// Records a vendor invoice against a purchase order (FRS 10.18); payment is Finance's, not made here.
class InvoiceDialog extends StatefulWidget {
  const InvoiceDialog({required this.order, super.key});

  final InventoryPurchaseOrder order;

  static Future<void> show(
    BuildContext context,
    InventoryPurchaseOrder order,
  ) => showFormPage(context, () => InvoiceDialog(order: order));

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _invoiceNumber = TextEditingController();
  final _date = TextEditingController(text: todayIST());
  late final _due = TextEditingController(text: widget.order.expectedDate);
  late final _subtotal = TextEditingController(
    text: widget.order.subtotal.toAmountText(),
  );
  late final _tax = TextEditingController(
    text: widget.order.tax.toAmountText(),
  );
  late final _discount = TextEditingController(
    text: widget.order.discount.toAmountText(),
  );
  final _receipts = <String>{};
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadReceipts(
        context.read<InventoryProvider>().access,
        widget.order.id,
      );
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _invoiceNumber,
      _date,
      _due,
      _subtotal,
      _tax,
      _discount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act('inventory-invoice-save', {
            'purchaseOrderId': widget.order.id,
            'invoiceNumber': _invoiceNumber.text.trim(),
            'invoiceDate': _date.text,
            'dueDate': _due.text,
            'subtotal': _v(_subtotal),
            'tax': _v(_tax),
            'discount': _v(_discount),
            'receiptIds': _receipts.toList(),
          }, requestId: _requestId),
      done: 'Invoice recorded successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.read<ProcurementProvider>();
    final goodsReceipts = context.watch<ProcurementProvider>().receipts;
    final vendor = procurementProvider.vendorName(widget.order.vendorId);
    final today = DateTime.now();

    return SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Vendor Invoice',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PO: ${widget.order.number} · $vendor',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _invoiceNumber,
              validator: requiredText,
              label: 'Vendor Invoice Number *',
              hintText: 'e.g. INV-2024-9912',
              icon: Icons.tag_rounded,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: dateField(
                    context,
                    _date,
                    'Invoice Date *',
                    first: today.subtract(const Duration(days: 365)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: dateField(
                    context,
                    _due,
                    'Due Date *',
                    first: today.subtract(const Duration(days: 365)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _subtotal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        (double.tryParse((value ?? '').trim()) ?? -1) < 0
                        ? 'Invalid'
                        : null,
                    label: 'Subtotal (₹)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: _tax,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: optionalNumber,
                    label: 'Tax (₹)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: optionalNumber,
                    label: 'Discount (₹)',
                  ),
                ),
              ],
            ),

            if (goodsReceipts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Link Receiving Goods Receipts (GRN)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final receipt in goodsReceipts)
                    FilterChip(
                      label: Text(
                        '${receipt.number}${receipt.reference == null ? '' : ' (${receipt.reference})'}',
                      ),
                      selected: _receipts.contains(receipt.id),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _receipts.add(receipt.id)
                            : _receipts.remove(receipt.id),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_busy ? 'Recording…' : 'Record Invoice'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
