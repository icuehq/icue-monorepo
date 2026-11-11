import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_orders.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/models/inventory_receiving.dart';

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

  /// Approvers and procurement see the branch's requests; everyone else their own.
  Future<List<InventoryPurchaseRequest>> requests(
    ModuleAccess access, {
    String? status,
  }) async {
    final collection = await branchCollection('inventoryPurchaseRequests');
    final wide =
        access.can('inventory.purchaseRequest.approve') ||
        access.can('inventory.procure.operate');
    Query<Map<String, dynamic>> q = collection;
    if (!wide) q = q.where('createdBy', isEqualTo: uid);
    if (status != null) q = q.where('status', isEqualTo: status);
    final snapshot = await q
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryPurchaseRequest.fromMap(document.id, document.data()),
    ];
  }

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

  Future<List<InventoryPurchaseOrder>> orders({String? status}) async {
    Query<Map<String, dynamic>> q = await branchCollection(
      'inventoryPurchaseOrders',
    );
    if (status != null) q = q.where('status', isEqualTo: status);
    final snapshot = await q
        .orderBy('createdAt', descending: true)
        .limit(50)
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
}
