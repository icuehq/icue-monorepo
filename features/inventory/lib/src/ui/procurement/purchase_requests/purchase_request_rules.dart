import 'package:inventory/inventory.dart';

/// What this user should do next on [request], or null when nothing waits on them.
String? purchaseNextAction(InventoryPurchaseRequest request, String uid) {
  final own = request.createdBy == uid;
  if (request.isPending) {
    return 'Awaiting your decision';
  }
  if (own && request.status == 'revision_requested') {
    return 'Returned: update and resubmit';
  }
  if (own && request.status == 'draft') return 'Draft: submit for approval';
  return null;
}
