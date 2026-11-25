import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/procurement_service.dart';
import 'package:inventory/src/services/procurement_writes.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Purchase requests. Needs `InventoryProvider.loadMasters()` first (stores).
@lazySingleton
class ProcurementProvider extends LoadingProvider {
  ProcurementProvider(this._service, this._stock);

  final ProcurementService _service;
  final StockService _stock;
  final _writes = ProcurementWrites();

  final Map<String, InventoryItem> items = {};

  /// Variants of the loaded requests' lines, by variant ID.
  final Map<String, InventoryVariant> variants = {};

  /// Paged list (server-side status filter and number search), narrowed to a store manager's stores.
  late final purchaseRequests = ListState<InventoryPurchaseRequest>(
    query: _service.requestsQuery,
    fromDocument: (document) =>
        InventoryPurchaseRequest.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (requests) => _loadNames(
      requests.expand(
        (purchaseRequest) =>
            purchaseRequest.lineItems.map((line) => line.itemId),
      ),
    ),
  );

  String itemName(String id) => items[id]?.name ?? id;

  /// Item name with its variant, e.g. `T-shirt · Blue · M`.
  String lineName(PurchaseRequestLine line) {
    final variant = variants[line.variantId];
    if (variant == null) return itemName(line.itemId);
    final label = variant.attrs.values.join(' · ');
    return '${itemName(line.itemId)} · ${label.isEmpty ? variant.sku : label}';
  }

  Future<void> _loadNames(Iterable<String> itemIds) async {
    final need = itemIds.where((id) => !items.containsKey(id)).toSet();
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  }

  /// One request by ID (item and variant names are loaded for its lines); null with [errorMessage] on failure.
  Future<InventoryPurchaseRequest?> request(String id) async {
    try {
      final purchaseRequest = await _service.request(id);
      if (purchaseRequest != null) {
        final lines = purchaseRequest.lineItems;
        await _loadNames(lines.map((line) => line.itemId));
        for (final itemId in {
          for (final line in lines)
            if (line.variantId != null && !variants.containsKey(line.variantId))
              line.itemId,
        }) {
          for (final variant in await _service.variants(itemId)) {
            variants[variant.id] = variant;
          }
        }
      }
      return purchaseRequest;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }

  /// Runs a purchase request write, or else a callable (asset receipts); returns its result or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return ProcurementWrites.names.contains(value)
          ? await _writes.run(value, data)
          : await _stock.call(value, data, requestId: requestId);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
