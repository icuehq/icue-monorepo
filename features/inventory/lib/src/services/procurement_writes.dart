import 'package:inventory/src/services/purchase_request_writes.dart';

/// Client-side purchase request writes (save, receive, close). Business checks live here;
/// `firestore.rules` checks who and which store. Each write stamps `lastWrite` for the audit log.
class ProcurementWrites {
  static final _requests = PurchaseRequestWrites();

  static final _handlers =
      <String, Future<Map<String, dynamic>> Function(Map<String, Object?>)>{
        'inventory-purchaseRequest-save': _requests.savePurchaseRequest,
        'inventory-purchaseRequest-receive': _requests.receivePurchaseRequest,
        'inventory-purchaseRequest-close': _requests.closePurchaseRequest,
      };

  /// Action names `ProcurementProvider.act` routes here instead of to a callable.
  static Iterable<String> get names => _handlers.keys;

  Future<Map<String, dynamic>> run(String name, Map<String, Object?> data) =>
      _handlers[name]?.call(data) ?? (throw ArgumentError.value(name, 'name'));
}
