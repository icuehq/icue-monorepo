import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

import '../support/driver.dart';

/// Guide 1.3 (purchase requests). Steps run once: each is skipped when its outcome is already on screen.
Future<void> procurementSteps(WidgetTester tester) async {
  Future<void> fillStarting(String prefix, String value, {int index = 0}) =>
      enter(tester, fieldStarting(prefix, index: index), value);

  await step(tester, '1.3.4 purchase request draft', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseRequests);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (await appears(tester, find.textContaining('PR/'))) return;
    await tapLabel(tester, 'New Request');
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
    await enter(tester, fieldStarting('Est. Unit Price', index: 1), '55000');
    await tapText(tester, 'Save as Draft');
    await waitFor(tester, find.textContaining('PR/'));
  });

  Future<void> openPurchaseRequest() async {
    await open(tester, InventoryRoutes.inventoryPurchaseRequests);
    await tapContaining(tester, 'PR/');
  }

  await step(tester, '1.3.5 edit the draft', () async {
    await openPurchaseRequest();
    if (!await appears(tester, find.textContaining('120 ×'))) return;
    await tapText(tester, 'Edit');
    await enter(tester, fieldStarting('Quantity'), '100');
    await tapText(tester, 'Save as Draft');
    await openPurchaseRequest();
    await waitFor(tester, find.textContaining('100 ×'));
  });

  await step(tester, '1.3.6 submit for approval', () async {
    await openPurchaseRequest();
    if (await appears(tester, find.text('Submit'))) {
      await tapText(tester, 'Submit');
    }
    await waitFor(tester, find.textContaining('Pending'));
  });

  await step(tester, '1.3.8 return needs a comment', () async {
    await openPurchaseRequest();
    if (!await appears(tester, find.text('Return'))) return;
    await tapText(tester, 'Return');
    await tapText(tester, 'Return', index: 1);
    await waitFor(tester, find.text('A comment is required'));
    await fillStarting(
      'Comment',
      'Please reduce laptop quantity from 5 to 2 due to quarterly budget ceiling.',
    );
    await tapText(tester, 'Return', index: 1);
    await waitFor(tester, find.textContaining('Returned'));
  });

  await step(tester, '1.3.9-1.3.10 resubmit and approve', () async {
    await openPurchaseRequest();
    if (await appears(tester, find.textContaining('Returned'))) {
      await tapText(tester, 'Edit');
      await enter(tester, fieldStarting('Quantity', index: 1), '2');
      await tapText(tester, 'Submit for Approval');
      await openPurchaseRequest();
    }
    if (await appears(tester, find.text('Approve'))) {
      await tapText(tester, 'Approve');
      await tapText(tester, 'Approve', index: 1);
    }
    await waitFor(tester, find.textContaining('Approved'));
  });
}
