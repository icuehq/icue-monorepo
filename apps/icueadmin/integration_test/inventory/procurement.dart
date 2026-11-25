import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

import '../support/driver.dart';

/// Guide 1.3 (purchase requests). Steps run once: each is skipped when its outcome is already on screen.
Future<void> procurementSteps(WidgetTester tester) async {
  Future<void> fillStarting(String prefix, String value, {int index = 0}) =>
      enter(tester, fieldStarting(prefix, index: index), value);

  await step(tester, '1.3.4 create a purchase request', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseRequests);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (await appears(tester, find.textContaining('PR/'))) return;
    await tapLabel(tester, 'New Request');
    await tapText(tester, 'Store');
    await tapText(tester, 'Central Main Store', index: 1);
    await tapText(tester, 'Priority');
    await tapText(tester, 'High', index: 1);
    await fillStarting(
      'Purpose',
      'Annual Examination & Office Supplies Requisition',
    );
    await pickDate(tester, 'Required by date *', 7);
    await tapText(tester, 'Add Item to Request');
    await tapContaining(tester, 'Ballpoint Pen');
    await enter(tester, fieldStarting('Quantity'), '120');
    await tapText(tester, 'Add Item to Request');
    await tapContaining(tester, 'Dell Latitude');
    await enter(tester, fieldStarting('Quantity', index: 1), '5');
    await tapText(tester, 'Create request');
    await waitFor(tester, find.textContaining('PR/'));
  });

  Future<void> openPurchaseRequest() async {
    await open(tester, InventoryRoutes.inventoryPurchaseRequests);
    await tapContaining(tester, 'PR/');
  }

  await step(tester, '1.3.5 edit before goods arrive', () async {
    await openPurchaseRequest();
    if (!await appears(tester, find.textContaining('Requested 120'))) return;
    await tapText(tester, 'Edit');
    await enter(tester, fieldStarting('Quantity'), '100');
    await tapText(tester, 'Save changes');
    await openPurchaseRequest();
    await waitFor(tester, find.textContaining('Requested 100'));
  });

  await step(tester, '1.3.6 record goods that arrived', () async {
    await openPurchaseRequest();
    if (await appears(tester, find.textContaining('Received 0'))) {
      await tapText(tester, 'Receive goods');
      await enter(tester, fieldStarting('Received in good condition'), '60');
      await enter(tester, fieldStarting('Damaged'), '5');
      await tapText(tester, 'Confirm receipt');
    }
    await waitFor(tester, find.textContaining('Partially received'));
  });
}
