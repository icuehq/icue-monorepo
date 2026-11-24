import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/procurement_service.dart';
import 'package:inventory/src/services/procurement_writes.dart';
import 'package:inventory/src/services/stock_service.dart';
import 'package:inventory/src/services/stock_writes.dart';

/// Purchase requests. Needs `InventoryProvider.loadMasters()` first (access).
@lazySingleton
class ProcurementProvider extends LoadingProvider {
  ProcurementProvider(this._service, this._stock);

  final ProcurementService _service;
  final StockService _stock;
  final _writes = ProcurementWrites();
  final _stockWrites = StockWrites();

  final Map<String, InventoryItem> items = {};

  /// Paged list (server-side status filter and number search).
  late final purchaseRequests = ListState<InventoryPurchaseRequest>(
    query: _service.requestsQuery,
    fromDocument: (document) =>
        InventoryPurchaseRequest.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (requests) => _loadNames(
      requests.expand(
        (purchaseRequest) => purchaseRequest.lineItems.map(
          (purchaseRequestLine) => purchaseRequestLine.itemId,
        ),
      ),
    ),
  );

  String get uid => _service.uid;

  String itemName(String id) => items[id]?.name ?? id;

  Future<void> _loadNames(Iterable<String> itemIds) async {
    final need = itemIds.where((i) => !items.containsKey(i)).toSet();
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  }

  /// One request by ID (item names are loaded for its lines); null with [errorMessage] on failure.
  Future<InventoryPurchaseRequest?> request(String id) async {
    try {
      final purchaseRequest = await _service.request(id);
      if (purchaseRequest != null) {
        await _loadNames(
          purchaseRequest.lineItems.map(
            (purchaseRequestLine) => purchaseRequestLine.itemId,
          ),
        );
      }
      return purchaseRequest;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }

  /// Runs a client write (purchase requests) or else a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return ProcurementWrites.names.contains(value)
          ? await _writes.run(value, data)
          : StockWrites.names.contains(value)
          ? await _stockWrites.run(value, data)
          : await _stock.call(value, data, requestId: requestId);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
