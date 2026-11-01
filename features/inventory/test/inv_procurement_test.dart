import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  InvPurchaseRequest pr(String status, {double ordered = 0}) =>
      InvPurchaseRequest.fromMap('p', {
        'status': status,
        'lines': [
          {'itemId': 'i', 'qty': 4, 'estPrice': 2.5, 'qtyOrdered': ordered},
        ],
        'history': [
          {'action': 'submit', 'comment': null},
        ],
      });

  test('status drives edit, approve and cancel', () {
    expect(pr('draft').isEditable, isTrue);
    expect(pr('revision_requested').isEditable, isTrue);
    expect(pr('pending').isEditable, isFalse);
    expect(pr('pending').isPending, isTrue);
    expect(pr('approved').isCancellable, isTrue);
    expect(pr('approved', ordered: 1).isCancellable, isFalse);
    expect(pr('rejected').isCancellable, isFalse);
    expect(pr('cancelled').isCancellable, isFalse);
  });

  test('parses lines, history and vendors', () {
    final r = pr('draft');
    expect(r.lines.single.estPrice, 2.5);
    expect(r.history.single.action, 'submit');
    final v = InvVendor.fromMap('v', {'code': 'V1', 'status': 'inactive'});
    expect(v.active, isFalse);
    expect(v.categoryIds, isEmpty);
  });
}
