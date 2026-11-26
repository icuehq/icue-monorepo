import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

InventoryCategory _category(Map<String, dynamic> data) =>
    InventoryCategory.fromMap('c', {'name': 'C', 'storeId': 's', ...data});

void main() {
  final approvers = [
    const CategoryApprover(roleId: 7, userIds: []),
    const CategoryApprover(roleId: 8, userIds: ['11', '12']),
  ];

  test('categoryAccessData derives the rule fields from approvers', () {
    final data = categoryAccessData(
      requesterRoleIds: [5],
      approvers: approvers,
    );
    expect(data['requesterRoleIds'], [5]);
    expect(data['approverRoleIds'], [7]);
    expect(data['approverIds'], ['11', '12']);
  });

  test('canRequest: empty means everyone, otherwise a matching role', () {
    expect(_category({}).canRequest([1]), isTrue);
    final gated = _category({
      'requesterRoleIds': [5],
    });
    expect(gated.canRequest([5, 9]), isTrue);
    expect(gated.canRequest([9]), isFalse);
  });

  test('canApprove: picked people, or anyone in a role with nobody picked', () {
    expect(_category({}).canApprove('1', []), isTrue);
    final gated = _category(
      categoryAccessData(requesterRoleIds: [], approvers: approvers),
    );
    expect(gated.canApprove('99', [7]), isTrue);
    expect(gated.canApprove('11', []), isTrue);
    expect(gated.canApprove('99', [8]), isFalse);
  });
}
