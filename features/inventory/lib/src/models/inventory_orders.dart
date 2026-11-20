import 'package:inventory/src/models/inventory_orders.g.dart';

export 'inventory_orders.g.dart';

// Quotations and purchase orders (Inv-4). Parse and display only; rules live in Cloud Functions.

extension OrderLineMembers on OrderLine {
  /// Still to be delivered or rejected on a purchase order line.
  double get due => quantity - quantityAccepted;
}

extension InventoryQuotationMembers on InventoryQuotation {
  bool get isDraft => status == 'draft';
}

extension InventoryPurchaseOrderMembers on InventoryPurchaseOrder {
  bool get isDraft => status == 'draft';
  bool get isIssued => status == 'issued';

  /// Header and price changes after issue (recorded as a revision).
  bool get canRevise => isIssued || status == 'acknowledged';
  bool get canCancel => isDraft || canRevise;
  bool get canReceive =>
      status == 'issued' ||
      status == 'acknowledged' ||
      status == 'partially_received';
  bool get canClose =>
      canRevise || status == 'partially_received' || status == 'fully_received';
}
