import 'package:inventory/src/models/inventory_receiving.g.dart';

export 'inventory_receiving.g.dart';

// Goods receiving notes and vendor invoices (Inv-5). Parse and display only; rules live in Cloud Functions.

extension InventoryInvoiceMembers on InventoryInvoice {
  bool get isCancelled => paymentStatus == 'cancelled';
  bool get isUnpaid => paymentStatus == 'unpaid';

  /// Stored status, or `overdue` for an unsettled invoice past [today] (`yyyy-mm-dd`) its due date.
  String statusOn(String today) =>
      (paymentStatus == 'unpaid' || paymentStatus == 'partially_paid') &&
          dueDate != null &&
          dueDate!.compareTo(today) < 0
      ? 'overdue'
      : paymentStatus;
}
