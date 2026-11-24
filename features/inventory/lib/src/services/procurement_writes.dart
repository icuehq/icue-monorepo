import 'package:inventory/src/services/purchase_request_writes.dart';

/// Client-side purchase request writes (save, submit, decide, cancel).
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
  };

  final _requests = PurchaseRequestWrites();

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, Object?> data,
  ) => switch (name) {
    'inventory-purchaseRequest-save' => _requests.savePurchaseRequest(data),
    'inventory-purchaseRequest-submit' => _requests.submitPurchaseRequest(data),
    'inventory-purchaseRequest-decide' => _requests.decidePurchaseRequest(data),
    'inventory-purchaseRequest-cancel' => _requests.cancelPurchaseRequest(data),
    _ => throw ArgumentError.value(name, 'name'),
  };
}
