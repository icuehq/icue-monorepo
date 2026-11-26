import 'package:inventory/src/models/inventory_masters.g.dart';

export 'inventory_masters.g.dart';

/// Tracking method of an item (FRS 10.3).
enum Tracking {
  quantity('Quantity'),
  batch('Batch'),
  asset('Asset');

  const Tracking(this.label);

  final String label;

  static Tracking parse(Object? value) => values.firstWhere(
    (tracking) => tracking.name == value,
    orElse: () => quantity,
  );
}

/// Firestore fields of a top-level category's request/approve settings.
/// `approverRoleIds` (roles with nobody picked) and `approverIds` (everyone
/// picked) are derived from [approvers] for `firestore.rules`.
Map<String, Object> categoryAccessData({
  required List<int> requesterRoleIds,
  required List<CategoryApprover> approvers,
}) => {
  'requesterRoleIds': requesterRoleIds,
  'approvers': [
    for (final approver in approvers)
      {'roleId': approver.roleId, 'userIds': approver.userIds},
  ],
  'approverRoleIds': [
    for (final approver in approvers)
      if (approver.userIds.isEmpty) approver.roleId,
  ],
  'approverIds': {for (final approver in approvers) ...approver.userIds}
      .toList(),
};

/// Who may request a top-level category's items and approve its requests.
extension CategoryAccess on InventoryCategory {
  /// No requester roles means every staff member may request.
  bool canRequest(List<int> roleIds) =>
      requesterRoleIds.isEmpty || requesterRoleIds.any(roleIds.contains);

  /// A picked person, or anyone holding a role with nobody picked.
  bool canApprove(String uid, List<int> roleIds) {
    // TODO(node): with no approvers the request goes to the requester's
    // default approver from Node (API pending); until then any staff may
    // approve. Keep in sync with categoryApprover() in firestore.rules.
    if (approvers.isEmpty) return true;
    return approverIds.contains(uid) || approverRoleIds.any(roleIds.contains);
  }
}
