import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';

/// Assets and maintenance (Inv-6): reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class AssetsService {
  Future<List<InventoryAsset>> assets({String? status}) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryAssets',
    );
    if (status != null) query = query.where('status', isEqualTo: status);
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryAsset.fromMap(document.id, document.data()),
    ];
  }

  Future<InventoryAsset?> asset(String id) async {
    final document = await (await branchCollection('inventoryAssets'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null ? null : InventoryAsset.fromMap(document.id, data);
  }

  /// A scan: the asset whose ID (document ID) or RFID tag equals [code] in this branch, or null.
  Future<InventoryAsset?> findByCode(String code) async {
    if (code.isEmpty || code.contains('/')) return null;
    final byId = await asset(code);
    if (byId != null) return byId;
    final snapshot = await (await branchCollection('inventoryAssets'))
        .where('rfidTag', isEqualTo: code)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return InventoryAsset.fromMap(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  Future<List<InventoryAssignment>> assignments(String assetId) async {
    final snapshot = await (await branchCollection('inventoryAssetAssignments'))
        .where('assetId', isEqualTo: assetId)
        .orderBy('assignedAt', descending: true)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryAssignment.fromMap(document.id, document.data()),
    ];
  }

  Future<List<AssetEvent>> history(String assetId) async {
    final snapshot = await (await branchCollection('inventoryAssets'))
        .doc(assetId)
        .collection('history')
        .orderBy('performedAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs) AssetEvent.fromMap(document.data()),
    ];
  }

  Future<List<InventoryMaintenance>> maintenance({
    String? status,
    String? assetId,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryMaintenanceJobs',
    );
    if (status != null) query = query.where('status', isEqualTo: status);
    if (assetId != null) query = query.where('assetId', isEqualTo: assetId);
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryMaintenance.fromMap(document.id, document.data()),
    ];
  }
}
