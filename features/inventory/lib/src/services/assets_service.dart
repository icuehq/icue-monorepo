import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_assets.dart';
import 'package:inventory/src/models/inv_masters.dart';

/// Assets and maintenance (Inv-6): reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class AssetsService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final claims =
        (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims;
    return FirebaseFirestore.instance.collection(
      'schools/${claims?['sid']}/$path',
    );
  }

  /// Rules need the campus filter on every list (`all` users need none); null when the user has no campus.
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> q,
    InvAccess a,
  ) => a.all
      ? q
      : a.campuses.isEmpty
      ? null
      : q.where('campusId', whereIn: a.campuses);

  Future<List<InvAsset>> assets(InvAccess a, {String? status}) async {
    var q = _scoped(await _coll('invAssets'), a);
    if (q == null) return [];
    if (status != null) q = q.where('status', isEqualTo: status);
    final snap = await q
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return [for (final d in snap.docs) InvAsset.fromMap(d.id, d.data())];
  }

  Future<InvAsset?> asset(String id) async {
    final d = await (await _coll('invAssets')).doc(id).get();
    final m = d.data();
    return m == null ? null : InvAsset.fromMap(d.id, m);
  }

  Future<List<InvAssignment>> assignments(InvAccess a, String assetId) async {
    final q = _scoped(
      (await _coll('invAssetAssignments')).where('assetId', isEqualTo: assetId),
      a,
    );
    if (q == null) return [];
    final snap = await q.orderBy('assignedAt', descending: true).get();
    return [for (final d in snap.docs) InvAssignment.fromMap(d.id, d.data())];
  }

  Future<List<AssetEvent>> history(InvAccess a, String assetId) async {
    final q = _scoped(
      (await _coll('invAssets')).doc(assetId).collection('history'),
      a,
    );
    if (q == null) return [];
    final snap = await q.orderBy('at', descending: true).limit(100).get();
    return [for (final d in snap.docs) AssetEvent.fromMap(d.data())];
  }

  Future<List<InvMaintenance>> maintenance(
    InvAccess a, {
    String? status,
    String? assetId,
  }) async {
    var q = _scoped(await _coll('invMaintenance'), a);
    if (q == null) return [];
    if (status != null) q = q.where('status', isEqualTo: status);
    if (assetId != null) q = q.where('assetId', isEqualTo: assetId);
    final snap = await q
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [for (final d in snap.docs) InvMaintenance.fromMap(d.id, d.data())];
  }
}
