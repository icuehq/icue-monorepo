import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';

/// Assets and maintenance (Inv-6): reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class AssetsService {
  /// Rules need the campus filter on every list (`all` users need none); null when the user has no campus.
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> query,
    ModuleAccess access,
  ) => access.restrictToCampuses(query);

  Future<List<InventoryAsset>> assets(
    ModuleAccess access, {
    String? status,
  }) async {
    var query = _scoped(await schoolCollection('inventoryAssets'), access);
    if (query == null) return [];
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
    final document = await (await schoolCollection('inventoryAssets'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null ? null : InventoryAsset.fromMap(document.id, data);
  }

  /// A scan: the asset whose ID or RFID tag equals [code] on the user's campuses, or null.
  Future<InventoryAsset?> findByCode(ModuleAccess access, String code) async {
    for (final field in ['assetId', 'rfidTag']) {
      final query = _scoped(
        (await schoolCollection('inventoryAssets'))
            .where(field, isEqualTo: code),
        access,
      );
      final snapshot = await query?.limit(1).get();
      if (snapshot != null && snapshot.docs.isNotEmpty) {
        return InventoryAsset.fromMap(
          snapshot.docs.first.id,
          snapshot.docs.first.data(),
        );
      }
    }
    return null;
  }

  Future<List<InventoryAssignment>> assignments(
    ModuleAccess access,
    String assetId,
  ) async {
    final query = _scoped(
      (await schoolCollection('inventoryAssetAssignments'))
          .where('assetId', isEqualTo: assetId),
      access,
    );
    if (query == null) return [];
    final snapshot = await query.orderBy('assignedAt', descending: true).get();
    return [
      for (final document in snapshot.docs)
        InventoryAssignment.fromMap(document.id, document.data()),
    ];
  }

  Future<List<AssetEvent>> history(ModuleAccess access, String assetId) async {
    final query = _scoped(
      (await schoolCollection('inventoryAssets'))
          .doc(assetId)
          .collection('history'),
      access,
    );
    if (query == null) return [];
    final snapshot = await query
        .orderBy('performedAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs) AssetEvent.fromMap(document.data()),
    ];
  }

  Future<List<InventoryMaintenance>> maintenance(
    ModuleAccess access, {
    String? status,
    String? assetId,
  }) async {
    var query = _scoped(
      await schoolCollection('inventoryMaintenanceJobs'),
      access,
    );
    if (query == null) return [];
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
