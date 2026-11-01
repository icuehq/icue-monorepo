import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_orders.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/models/inventory_receiving.dart';
import 'package:inventory/src/services/procurement_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Vendors and purchase requests. Needs `InventoryProvider.loadMasters()` first (access).
@lazySingleton
class ProcurementProvider extends ChangeNotifier {
  ProcurementProvider(this._service, this._stock);

  final ProcurementService _service;
  final StockService _stock;

  final Map<String, InventoryItem> items = {};
  List<InventoryVendor> vendors = [];
  List<InventoryPurchaseRequest> requests = [];
  List<InventoryQuotation> quotations = [];
  List<InventoryPurchaseOrder> orders = [];
  List<InventoryGoodsReceipt> receipts = [];
  List<InventoryInvoice> invoices = [];
  String? errorMessage;
  bool isLoading = false;

  String get uid => _service.uid;

  String itemName(String id) => items[id]?.name ?? id;

  String vendorName(String id) {
    for (final vendor in vendors) {
      if (vendor.id == id) return vendor.name;
    }
    return id;
  }

  Future<void> _loadNames(Iterable<String> itemIds) async {
    if (vendors.isEmpty) vendors = await _service.vendors();
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

  Future<void> loadQuotations(String purchaseRequestId) => _load(() async {
    quotations = await _service.quotations(purchaseRequestId)
      ..sort((left, right) => left.total.compareTo(right.total));
    await _loadNames(
      quotations.expand(
        (quotation) => quotation.lineItems.map((orderLine) => orderLine.itemId),
      ),
    );
  });

  Future<void> loadOrders(ModuleAccess access, {String? status}) =>
      _load(() async {
        orders = await _service.orders(access, status: status);
        await _loadNames(
          orders.expand(
            (purchaseOrder) =>
                purchaseOrder.lineItems.map((orderLine) => orderLine.itemId),
          ),
        );
      });

  Future<void> loadReceipts(ModuleAccess access, String purchaseOrderId) =>
      _load(() async {
        receipts = await _service.receipts(access, purchaseOrderId);
        await _loadNames(
          receipts.expand(
            (goodsReceipt) => goodsReceipt.lineItems.map(
              (goodsReceiptLine) => goodsReceiptLine.itemId,
            ),
          ),
        );
      });

  Future<void> loadInvoices(
    ModuleAccess access, {
    String? purchaseOrderId,
    String? status,
  }) => _load(() async {
    invoices = await _service.invoices(
      access,
      purchaseOrderId: purchaseOrderId,
      status: status,
    );
    await _loadNames(const []);
  });

  Future<void> _load(Future<void> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVendors() => _load(() async {
    vendors = await _service.vendors();
  });

  Future<void> loadRequests(ModuleAccess access, {String? status}) =>
      _load(() async {
        requests = await _service.requests(access, status: status);
        final need = requests
            .expand(
              (purchaseRequest) => purchaseRequest.lineItems.map(
                (purchaseRequestLine) => purchaseRequestLine.itemId,
              ),
            )
            .where((i) => !items.containsKey(i));
        if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
      });

  /// Runs a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _stock.call(value, data, requestId: requestId);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
