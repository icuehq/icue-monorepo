import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('balance and quantity formatting', () {
    final b = InvBalance.fromMap('s__i__-__-', {
      'storeId': 's',
      'itemId': 'i',
      'qtyAvailable': 7,
      'qtyIssuedTotal': 2.5,
      'belowReorder': true,
    });
    expect(b.available, 7);
    expect(b.issuedTotal, 2.5);
    expect(b.belowReorder, isTrue);
    expect(b.batchNo, isNull);
    expect(fmtQty(7), '7');
    expect(fmtQty(2.5), '2.5');
  });

  test('request status drives which actions apply', () {
    InvIssueRequest req(String status) => InvIssueRequest.fromMap('r', {
      'status': status,
      'lines': [
        {'itemId': 'i', 'qtyRequested': 4, 'qtyApproved': null, 'qtyIssued': 0},
      ],
    });
    expect(req('pending').isPending, isTrue);
    expect(req('approved').isIssuable, isTrue);
    expect(req('partially_issued').isIssuable, isTrue);
    expect(req('issued').isIssuable, isFalse);
    expect(req('pending').lines.single.approved, isNull);
  });

  test('issue line outstanding and transfer in-transit state', () {
    final l = IssueLine.fromMap({'qty': 6, 'qtyReturned': 4, 'balanceId': 'b'});
    expect(l.outstanding, 2);
    final t = InvTransfer.fromMap('t', {
      'status': 'partially_received',
      'from': {'storeId': 'a', 'campusId': 1},
      'to': {'storeId': 'b', 'campusId': 2},
      'requested': [
        {'itemId': 'i', 'qty': 6},
      ],
    });
    expect(t.inTransit, isTrue);
    expect(t.toCampusId, 2);
    expect(t.requested.single.qty, 6);
  });
}
