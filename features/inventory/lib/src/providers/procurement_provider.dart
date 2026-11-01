import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/models/inv_orders.dart';
import 'package:inventory/src/models/inv_procurement.dart';
import 'package:inventory/src/services/procurement_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Vendors and purchase requests. Needs `InventoryProvider.loadMasters()` first (access).
@lazySingleton
class ProcurementProvider extends ChangeNotifier {
  ProcurementProvider(this._service, this._stock);

  final ProcurementService _service;
  final StockService _stock;

  final Map<String, InvItem> items = {};
  List<InvVendor> vendors = [];
  List<InvPurchaseRequest> requests = [];
  List<InvQuotation> quotations = [];
  List<InvPurchaseOrder> orders = [];
  String? errorMessage;
  bool isLoading = false;

  String get uid => _service.uid;

  String itemName(String id) => items[id]?.name ?? id;

  String vendorName(String id) {
    for (final v in vendors) {
      if (v.id == id) return v.name;
    }
    return id;
  }

  Future<void> _loadNames(Iterable<String> itemIds) async {
    if (vendors.isEmpty) vendors = await _service.vendors();
    final need = itemIds.where((i) => !items.containsKey(i)).toSet();
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  }

  /// One request by ID (item names are loaded for its lines); null with [errorMessage] on failure.
  Future<InvPurchaseRequest?> request(String id) async {
    try {
      final r = await _service.request(id);
      if (r != null) await _loadNames(r.lines.map((l) => l.itemId));
      return r;
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> loadQuotations(String prId) => _load(() async {
    quotations = await _service.quotations(prId)
      ..sort((a, b) => a.total.compareTo(b.total));
    await _loadNames(quotations.expand((q) => q.lines.map((l) => l.itemId)));
  });

  Future<void> loadOrders(InvAccess a, {String? status}) => _load(() async {
    orders = await _service.orders(a, status: status);
    await _loadNames(orders.expand((o) => o.lines.map((l) => l.itemId)));
  });

  Future<void> _load(Future<void> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVendors() => _load(() async {
    vendors = await _service.vendors();
  });

  Future<void> loadRequests(InvAccess a, {String? status}) => _load(() async {
    requests = await _service.requests(a, status: status);
    final need = requests
        .expand((r) => r.lines.map((l) => l.itemId))
        .where((i) => !items.containsKey(i));
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  });

  /// Runs a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String fn,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _stock.call(fn, data, requestId: requestId);
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return null;
    }
  }

  String _message(Object e) =>
      e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
}
