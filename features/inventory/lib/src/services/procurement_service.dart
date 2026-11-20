import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart' show todayIST;
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_orders.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/models/inventory_receiving.dart';
import 'package:inventory/src/providers/list_state.dart';

/// Vendors and purchase requests (Inv-3): reads and vendor writes go to Firestore; request, quotation and invoice writes are `ProcurementWrites`.
@lazySingleton
class ProcurementService {
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<List<InventoryVendor>> vendors() async {
    final snapshot = await (await branchCollection('inventoryVendors'))
        .orderBy('name')
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryVendor.fromMap(document.id, document.data()),
    ];
  }

  /// Edits the vendor `id`, or adds a new one under an auto-generated Firestore ID.
  Future<void> saveVendor(Map<String, Object?> data) async {
    final fields = {...data};
    final id = fields.remove('id') as String?;
    final collection = await branchCollection('inventoryVendors');
    if (id != null) {
      await collection.doc(id).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await collection.add({
      'status': 'active',
      ...fields,
      'documents': <Object?>[],
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setVendorActive(String id, {required bool active}) =>
      setMasterActive('inventoryVendors', id, active: active);

  /// The branch's purchase requests: [status] filter, request-number prefix [search].
  Future<ListQuery> requestsQuery(String? status, String search) async =>
      filteredQuery(
        await branchCollection('inventoryPurchaseRequests'),
        status: status,
        search: search,
      );

  /// Quotations of one request (equality query; sorted by the caller).
  Future<List<InventoryQuotation>> quotations(String purchaseRequestId) async {
    final snapshot = await (await branchCollection('inventoryQuotations'))
        .where('purchaseRequestId', isEqualTo: purchaseRequestId)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryQuotation.fromMap(document.id, document.data()),
    ];
  }

  /// Purchase orders for the list: [status] filter, PO-number prefix [search].
  Future<ListQuery> ordersQuery(String? status, String search) async =>
      filteredQuery(
        await branchCollection('inventoryPurchaseOrders'),
        status: status,
        search: search,
      );

  /// Orders raised from any of [quotationIds] (at most 30 per Firestore `whereIn`).
  Future<List<InventoryPurchaseOrder>> ordersOfQuotations(
    List<String> quotationIds,
  ) async {
    if (quotationIds.isEmpty) return const [];
    final snapshot = await (await branchCollection('inventoryPurchaseOrders'))
        .where('quotationId', whereIn: quotationIds.take(30).toList())
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryPurchaseOrder.fromMap(document.id, document.data()),
    ];
  }

  Future<InventoryPurchaseRequest?> request(String id) async {
    final document = await (await branchCollection('inventoryPurchaseRequests'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null
        ? null
        : InventoryPurchaseRequest.fromMap(document.id, data);
  }

  /// Deliveries received against one order, newest first.
  Future<List<InventoryGoodsReceipt>> receipts(String purchaseOrderId) async {
    final snapshot = await (await branchCollection('inventoryReceipts'))
        .where('purchaseOrderId', isEqualTo: purchaseOrderId)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryGoodsReceipt.fromMap(document.id, document.data()),
    ]..sort((left, right) => right.number.compareTo(left.number));
  }

  Future<List<InventoryInvoice>> invoices({
    String? purchaseOrderId,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryInvoices',
    );
    if (purchaseOrderId != null) {
      query = query.where('purchaseOrderId', isEqualTo: purchaseOrderId);
    }
    if (status != null) query = query.where('paymentStatus', isEqualTo: status);
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryInvoice.fromMap(document.id, document.data()),
    ];
  }

  /// Invoices for the list: payment [status] (or `overdue`: unpaid past due date, no
  /// search) and invoice-number prefix [search] as typed.
  Future<ListQuery> invoicesQuery(String? status, String search) async {
    final collection = await branchCollection('inventoryInvoices');
    if (status == 'overdue') {
      return collection
          .where('paymentStatus', whereIn: const ['unpaid', 'partially_paid'])
          .where('dueDate', isLessThan: dayTimestamp(todayIST()))
          .orderBy('dueDate');
    }
    return filteredQuery(
      collection,
      status: status,
      statusField: 'paymentStatus',
      search: search,
      searchField: 'invoiceNumber',
      upperCase: false,
    );
  }
}
