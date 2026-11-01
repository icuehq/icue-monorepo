import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/models/inv_procurement.dart';

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
}
