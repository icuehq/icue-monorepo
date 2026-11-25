import 'package:icue_firebase/icue_firebase.dart'
    show PurchaseRequestStatus, openPurchaseRequestStatuses;
import 'package:inventory/src/models/inventory_procurement.g.dart';

export 'inventory_procurement.g.dart';

/// Purchase requests: no approval; goods are recorded on the request as they arrive.

extension InventoryPurchaseRequestMembers on InventoryPurchaseRequest {
  /// Lines may change only until the first goods arrive.
  bool get isEditable => status == PurchaseRequestStatus.open;

  /// Goods can still be received, and the request closed.
  bool get isOpen => openPurchaseRequestStatuses.contains(status);
}

extension PurchaseRequestLineMembers on PurchaseRequestLine {
  /// Units still to arrive.
  double get pending {
    final left = quantity - received - damaged;
    return left > 0 ? left : 0;
  }
}
