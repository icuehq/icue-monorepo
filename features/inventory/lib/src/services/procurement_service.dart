import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_procurement.dart';
import 'package:inventory/src/providers/list_state.dart';

/// Purchase requests (Inv-3): reads go to Firestore; writes are `ProcurementWrites`.
@lazySingleton
class ProcurementService {
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// The branch's purchase requests: [status] filter, request-number prefix [search].
  Future<ListQuery> requestsQuery(String? status, String search) async =>
      filteredQuery(
        await branchCollection('inventoryPurchaseRequests'),
        status: status,
        search: search,
      );

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
