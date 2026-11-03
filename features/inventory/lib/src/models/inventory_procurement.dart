import 'package:icue_firebase/icue_firebase.dart'
    show
        cancellablePurchaseRequestStatuses,
        editablePurchaseRequestStatuses,
        orderablePurchaseRequestStatuses;
import 'package:inventory/src/models/inventory_procurement.g.dart';

export 'inventory_procurement.g.dart';

/// Vendors and purchase requests (Inv-3). Parse and display only; rules live in Cloud Functions.

extension InventoryPurchaseRequestMembers on InventoryPurchaseRequest {
  /// The requester may edit and (re)submit these.
  bool get isEditable => editablePurchaseRequestStatuses.contains(status);
  bool get isPending => status == 'pending';

  /// Quotations and POs may be raised against these.
  bool get isOrderable => orderablePurchaseRequestStatuses.contains(status);

  /// Cancelled requests stay on record; ordered quantity blocks cancellation.
  bool get isCancellable =>
      cancellablePurchaseRequestStatuses.contains(status) &&
      lineItems.every(
        (purchaseRequestLine) => purchaseRequestLine.quantityOrdered == 0,
      );
}
