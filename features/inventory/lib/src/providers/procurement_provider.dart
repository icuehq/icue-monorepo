import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_orders.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/models/inventory_receiving.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/providers/loading_provider.dart';
import 'package:inventory/src/services/procurement_service.dart';
import 'package:inventory/src/services/procurement_writes.dart';
import 'package:inventory/src/services/stock_service.dart';
import 'package:inventory/src/services/stock_writes.dart';

/// Vendors and purchase requests. Needs `InventoryProvider.loadMasters()` first (access).
@lazySingleton
class ProcurementProvider extends LoadingProvider {
  ProcurementProvider(this._service, this._stock);

  final ProcurementService _service;
  final StockService _stock;
  final _writes = ProcurementWrites();
  final _stockWrites = StockWrites();

  final Map<String, InventoryItem> items = {};
  List<InventoryVendor> vendors = [];
  List<InventoryQuotation> quotations = [];
  List<InventoryPurchaseOrder> orders = [];

  /// Paged lists (server-side status filter and number search): purchase orders,
  /// purchase requests and vendor invoices.
  late final purchaseOrders = ListState<InventoryPurchaseOrder>(
    query: _service.ordersQuery,
    fromDocument: (document) =>
        InventoryPurchaseOrder.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
  );
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
  late final invoiceList = ListState<InventoryInvoice>(
    query: _service.invoicesQuery,
    fromDocument: (document) =>
        InventoryInvoice.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
  );
  List<InventoryGoodsReceipt> receipts = [];
  List<InventoryInvoice> invoices = [];

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

  Future<void> loadQuotations(String purchaseRequestId) => load(() async {
    quotations = await _service.quotations(purchaseRequestId)
      ..sort((left, right) => left.total.compareTo(right.total));
    await _loadNames(
      quotations.expand(
        (quotation) => quotation.lineItems.map((orderLine) => orderLine.itemId),
      ),
    );
  });

  /// Orders raised from [quotations], to show which quotation already has one.
  Future<void> loadQuotationOrders() => load(() async {
    orders = await _service.ordersOfQuotations([
      for (final quotation in quotations) quotation.id,
    ]);
  });

  Future<void> loadReceipts(String purchaseOrderId) => load(() async {
    receipts = await _service.receipts(purchaseOrderId);
    await _loadNames(
      receipts.expand(
        (goodsReceipt) => goodsReceipt.lineItems.map(
          (goodsReceiptLine) => goodsReceiptLine.itemId,
        ),
      ),
    );
  });

  Future<void> loadInvoices({String? purchaseOrderId, String? status}) =>
      load(() async {
        invoices = await _service.invoices(
          purchaseOrderId: purchaseOrderId,
          status: status,
        );
        await _loadNames(const []);
      });

  /// Loads vendors once, so lists can show vendor names.
  Future<void> ensureVendors() async {
    if (vendors.isEmpty) await loadVendors();
  }

  Future<void> loadVendors() => load(() async {
    vendors = await _service.vendors();
  });

  /// Saves a vendor; returns an empty map, or null with [errorMessage] set.
  Future<Map<String, dynamic>?> saveVendor(Map<String, Object?> data) =>
      _vendorWrite(() => _service.saveVendor(data));

  Future<Map<String, dynamic>?> setVendorActive(
    String id, {
    required bool active,
  }) => _vendorWrite(() => _service.setVendorActive(id, active: active));

  Future<Map<String, dynamic>?> _vendorWrite(
    Future<void> Function() write,
  ) async {
    errorMessage = null;
    try {
      await write();
      return {};
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }

  /// Runs a client write (purchase requests, quotations, draft purchase orders, invoices) or else a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
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
