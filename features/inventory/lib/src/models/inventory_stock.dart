import 'package:inventory/src/models/inventory_stock.g.dart';

export 'inventory_stock.g.dart';

/// Stock models (Inv-2). Parse and display only; every rule lives in Cloud Functions.

extension InventoryIssueRequestMembers on InventoryIssueRequest {
  bool get isPending => status == 'pending';
  bool get isIssuable => status == 'approved' || status == 'partially_issued';
}

extension IssueLineMembers on IssueLine {
  double get outstanding => quantity - returned;
}

extension InventoryUnavailableMembers on InventoryUnavailable {
  bool get isOpen => status != 'resolved';
}
