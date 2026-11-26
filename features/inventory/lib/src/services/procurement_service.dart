import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/inventory_service.dart';

/// Purchase requests: reads go to Firestore; writes are `ProcurementWrites`.
@lazySingleton
class ProcurementService {
  ProcurementService(this._inventory);

  /// Knows which stores a store manager works in.
  final InventoryService _inventory;

  /// Purchase requests of the stores the user may see: [status] filter, request-number prefix [search]
  /// (`12` finds `PR/<this year>/000012`).
  Future<ListQuery> requestsQuery(String? status, String search) async {
    ListQuery query = await branchCollection('inventoryPurchaseRequests');
    final assigned = await _inventory.assignedStoreIds();
    if (assigned != null) query = _inventory.inStores(query, assigned);
    var number = search.trim();
    if (RegExp(r'^\d+$').hasMatch(number)) {
      final year = DateTime.now().toIndianTime().financialYear;
      number = 'PR/$year/${number.padLeft(6, '0')}';
    }
    return filteredQuery(query, status: status, search: number);
  }

  Future<List<InventoryVariant>> variants(String itemId) =>
      _inventory.variants(itemId);

  Future<InventoryPurchaseRequest?> request(String id) async {
    final document = await (await branchCollection('inventoryPurchaseRequests'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null
        ? null
        : InventoryPurchaseRequest.fromMap(document.id, data);
  }
}
