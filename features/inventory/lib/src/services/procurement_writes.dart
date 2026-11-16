import 'package:inventory/src/services/invoice_writes.dart';
import 'package:inventory/src/services/purchase_order_writes.dart';
import 'package:inventory/src/services/purchase_request_writes.dart';
import 'package:inventory/src/services/quotation_writes.dart';

/// Client-side purchase request, quotation, purchase order (save, issue, revise, acknowledge, cancel, close) and invoice writes.
///
/// Business checks live here, not in `firestore.rules`. There is no audit log,
/// no approver notification, and no re-validation of items,
/// variants or unit consistency.
class ProcurementWrites {
  /// Action names `ProcurementProvider.act` routes here instead of to a callable.
  static const names = {
    'inventory-purchaseRequest-save',
    'inventory-purchaseRequest-submit',
    'inventory-purchaseRequest-decide',
    'inventory-purchaseRequest-cancel',
    'inventory-quotation-save',
    'inventory-quotation-select',
    'inventory-purchaseOrder-save',
    'inventory-purchaseOrder-issue',
    'inventory-purchaseOrder-revise',
    'inventory-purchaseOrder-acknowledge',
    'inventory-purchaseOrder-cancel',
    'inventory-purchaseOrder-close',
    'inventory-invoice-save',
    'inventory-invoice-setPayment',
    'inventory-invoice-cancel',
  };

  final _requests = PurchaseRequestWrites();
  final _quotations = QuotationWrites();
  final _orders = PurchaseOrderWrites();
  final _invoices = InvoiceWrites();

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, Object?> data,
  ) => switch (name) {
    'inventory-purchaseRequest-save' => _requests.savePurchaseRequest(data),
    'inventory-purchaseRequest-submit' => _requests.submitPurchaseRequest(data),
    'inventory-purchaseRequest-decide' => _requests.decidePurchaseRequest(data),
    'inventory-purchaseRequest-cancel' => _requests.cancelPurchaseRequest(data),
    'inventory-quotation-save' => _quotations.saveQuotation(data),
    'inventory-quotation-select' => _quotations.selectQuotation(data),
    'inventory-purchaseOrder-save' => _orders.savePurchaseOrder(data),
    'inventory-purchaseOrder-issue' => _orders.issuePurchaseOrder(data),
    'inventory-purchaseOrder-revise' => _orders.revisePurchaseOrder(data),
    'inventory-purchaseOrder-acknowledge' => _orders.acknowledgePurchaseOrder(
      data,
    ),
    'inventory-purchaseOrder-cancel' => _orders.endPurchaseOrder(
      data,
      cancel: true,
    ),
    'inventory-purchaseOrder-close' => _orders.endPurchaseOrder(
      data,
      cancel: false,
    ),
    'inventory-invoice-save' => _invoices.saveInvoice(data),
    'inventory-invoice-setPayment' => _invoices.setInvoicePayment(data),
    'inventory-invoice-cancel' => _invoices.cancelInvoice(data),
    _ => throw ArgumentError.value(name, 'name'),
  };
}
