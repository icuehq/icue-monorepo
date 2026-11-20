import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/inventory_service.dart';

/// Assets and maintenance (Inv-6): reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class AssetsService {
  AssetsService(this._inventory);

  /// Knows which stores a store manager works in.
  final InventoryService _inventory;

  /// Assets: [status] filter, name prefix [search] as typed, one [storeId] when chosen.
  Future<ListQuery> assetsQuery(
    String? status,
    String search, {
    String? storeId,
  }) async {
    ListQuery query = await branchCollection('inventoryAssets');
    final assigned = await _inventory.assignedStoreIds();
    // A chosen store is one of the user's visible stores, so it replaces the assigned-stores narrowing.
    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    } else if (assigned != null) {
      query = _inventory.inStores(query, assigned);
    }
    return filteredQuery(
      query,
      status: status,
      search: search,
      searchField: 'name',
      upperCase: false,
    );
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

  /// Maintenance jobs: [status] filter, job-number prefix [search].
  Future<ListQuery> maintenanceQuery(String? status, String search) async =>
      filteredQuery(
        await branchCollection('inventoryMaintenanceJobs'),
        status: status,
        search: search,
      );
}
