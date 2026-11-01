import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/models/inv_orders.dart';
import 'package:inventory/src/models/inv_procurement.dart';
import 'package:inventory/src/models/inv_receiving.dart';

/// Vendors and purchase requests (Inv-3): reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class ProcurementService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final claims =
        (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims;
    return FirebaseFirestore.instance.collection(
      'schools/${claims?['sid']}/$path',
    );
  }

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<List<InvVendor>> vendors() async {
    final snap = await (await _coll('invVendors')).orderBy('name').get();
    return [for (final d in snap.docs) InvVendor.fromMap(d.id, d.data())];
  }

  /// Approvers and procurement see the campus's requests; everyone else their own (rules need the campus filter).
  Future<List<InvPurchaseRequest>> requests(
    InvAccess a, {
    String? status,
  }) async {
    final coll = await _coll('invPurchaseRequests');
    final wide = a.can('inv.pr.approve') || a.can('inv.procure.operate');
    Query<Map<String, dynamic>> q = coll;
    if (!wide) {
      q = q.where('createdBy', isEqualTo: uid);
    } else if (!a.all) {
      if (a.campuses.isEmpty) return [];
      q = q.where('campusId', whereIn: a.campuses);
    }
    if (status != null) q = q.where('status', isEqualTo: status);
    final snap = await q.orderBy('createdAt', descending: true).limit(50).get();
    return [
      for (final d in snap.docs) InvPurchaseRequest.fromMap(d.id, d.data()),
    ];
  }

  /// Quotations of one request (equality query; sorted by the caller).
  Future<List<InvQuotation>> quotations(String prId) async {
    final snap = await (await _coll('invQuotations'))
        .where('prId', isEqualTo: prId)
        .get();
    return [for (final d in snap.docs) InvQuotation.fromMap(d.id, d.data())];
  }

  /// Procurement sees orders of its campuses; receiving staff only those due at their campuses (rules need the matching filter).
  Future<List<InvPurchaseOrder>> orders(InvAccess a, {String? status}) async {
    if (!a.all && a.campuses.isEmpty) return [];
    final buyer = a.can('inv.procure.operate');
    Query<Map<String, dynamic>> q = await _coll('invPurchaseOrders');
    if (!a.all) {
      q = q.where(buyer ? 'campusId' : 'deliveryCampusId', whereIn: a.campuses);
    }
    if (status != null) q = q.where('status', isEqualTo: status);
    final snap = await q.orderBy('createdAt', descending: true).limit(50).get();
    return [
      for (final d in snap.docs) InvPurchaseOrder.fromMap(d.id, d.data()),
    ];
  }

  Future<InvPurchaseRequest?> request(String id) async {
    final d = await (await _coll('invPurchaseRequests')).doc(id).get();
    final m = d.data();
    return m == null ? null : InvPurchaseRequest.fromMap(d.id, m);
  }

  /// Deliveries received against one order, newest first (rules need the campus filter).
  Future<List<InvGrn>> receipts(InvAccess a, String poId) async {
    if (!a.all && a.campuses.isEmpty) return [];
    Query<Map<String, dynamic>> q = (await _coll('invReceipts'))
        .where('poId', isEqualTo: poId);
    if (!a.all) q = q.where('campusId', whereIn: a.campuses);
    final snap = await q.get();
    return [for (final d in snap.docs) InvGrn.fromMap(d.id, d.data())]
      ..sort((a, b) => b.number.compareTo(a.number));
  }

  Future<List<InvInvoice>> invoices(
    InvAccess a, {
    String? poId,
    String? status,
  }) async {
    if (!a.all && a.campuses.isEmpty) return [];
    Query<Map<String, dynamic>> q = await _coll('invInvoices');
    if (!a.all) q = q.where('campusId', whereIn: a.campuses);
    if (poId != null) q = q.where('poId', isEqualTo: poId);
    if (status != null) q = q.where('paymentStatus', isEqualTo: status);
    final snap = await q.orderBy('createdAt', descending: true).limit(50).get();
    return [for (final d in snap.docs) InvInvoice.fromMap(d.id, d.data())];
  }
}
