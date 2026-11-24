import 'package:icue_firebase/icue_firebase.dart'
    show cancellablePurchaseRequestStatuses, editablePurchaseRequestStatuses;
import 'package:inventory/src/models/inventory_procurement.g.dart';

export 'inventory_procurement.g.dart';

/// Purchase requests (Inv-3). Parse and display only; rules live in Cloud Functions.

extension InventoryPurchaseRequestMembers on InventoryPurchaseRequest {
  /// The requester may edit and (re)submit these.
  bool get isEditable => editablePurchaseRequestStatuses.contains(status);
  bool get isPending => status == 'pending';

  /// Cancelled requests stay on record.
  bool get isCancellable => cancellablePurchaseRequestStatuses.contains(status);
}
