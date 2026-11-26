import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/inventory_service.dart';

/// Asset management and maintenance: reads from Firestore, writes are callables (see `StockService.call`).
@lazySingleton
class AssetsService {
  AssetsService(this._inventory);

  /// Knows which stores a store manager works in.
  final InventoryService _inventory;

  /// Registered statuses: everything a unit can be once its details are entered.
  static final registeredStatuses = [
    for (final status in AssetStatus.values)
      if (status != AssetStatus.unregistered) status,
  ];

  /// Narrows [query] to the stores the user may see, or to the chosen [storeId].
  Future<ListQuery> _inScope(ListQuery query, String? storeId) async {
    final assigned = await _inventory.assignedStoreIds();
    // A chosen store is one of the user's visible stores, so it replaces the assigned-stores narrowing.
    if (storeId != null) return query.where('storeId', isEqualTo: storeId);
    return assigned == null ? query : _inventory.inStores(query, assigned);
  }

  /// The register (registered assets, optional [status] filter) or, with [unregistered], the received units still
  /// waiting for their details. Name prefix [search] as typed, one [storeId] when chosen.
  Future<ListQuery> assetsQuery(
    String? status,
    String search, {
    String? storeId,
    bool unregistered = false,
  }) async {
    var query = await _inScope(
      await branchCollection('inventoryAssets'),
      storeId,
    );
    if (unregistered) {
      query = query.where('status', isEqualTo: AssetStatus.unregistered);
    } else if (status == null) {
      query = query.where('status', whereIn: registeredStatuses);
    }
    return filteredQuery(
      query,
      status: unregistered ? null : status,
      search: search,
      searchField: 'name',
      upperCase: false,
    );
  }

  /// Unregistered units counted per item and store (for the stock list).
  /// ponytail: reads at most 500 unregistered units; page or keep a counter if a branch ever has more waiting.
  Future<List<UnregisteredStock>> unregisteredStock({String? storeId}) async {
    final snapshot = await (await _inScope(
      (await branchCollection('inventoryAssets'))
          .where('status', isEqualTo: AssetStatus.unregistered),
      storeId,
    )).limit(500).get();
    final counts = <(String, String), int>{};
    for (final document in snapshot.docs) {
      final key = (
        document.data()['itemId'] as String,
        document.data()['storeId'] as String,
      );
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        UnregisteredStock(itemId: key.$1, storeId: key.$2, count: value),
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

  /// Maintenance jobs: [status] filter, job-number prefix [search].
  Future<ListQuery> maintenanceQuery(String? status, String search) async =>
      filteredQuery(
        await branchCollection('inventoryMaintenanceJobs'),
        status: status,
        search: search,
      );
}
