import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

import '../support/driver.dart';

/// Guide 1.2 (stock). Steps run once: each is skipped when its outcome is already on screen.
Future<void> stockSteps(WidgetTester tester) async {
  Future<void> receive({
    required String item,
    required String reference,
    required String quantity,
    String? batch,
    int? expiryDays,
  }) async {
    await open(tester, InventoryRoutes.inventoryReceive);
    await tapText(tester, 'Store');
    await tapText(tester, 'Central Main Store', index: 1);
    await fill(tester, 'Reference number / Challan (optional)', reference);
    await tapLabel(tester, 'Add item');
    await tapContaining(tester, item);
    await fill(tester, 'Accepted', quantity);
    if (batch != null) {
      await fill(tester, 'Batch number', batch);
      await pickDate(tester, 'Expiry date', expiryDays!);
    }
    await tapContaining(tester, 'Confirm Receiving');
  }

  await step(tester, '1.2.1 receive opening stock', () async {
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.text('Store Stock'));
    if (await appears(tester, find.textContaining('PEN-BLU-01'))) return;
    await receive(item: 'Ballpoint Pen', reference: 'OP-2024-PEN', quantity: '100');
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.textContaining('PEN-BLU-01'));
    await waitFor(tester, find.textContaining('100'));
  });

  await step(tester, '1.2.2 receive batch stock', () async {
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.text('Store Stock'));
    if (!await appears(tester, find.textContaining('BATCH-M1'))) {
      await receive(item: 'Pasteurized Milk', reference: 'OP-2024-MILK-1', quantity: '20', batch: 'BATCH-M1', expiryDays: 5);
    }
    await open(tester, InventoryRoutes.inventoryStock);
    if (!await appears(tester, find.textContaining('BATCH-M2'))) {
      await receive(item: 'Pasteurized Milk', reference: 'OP-2024-MILK-2', quantity: '10', batch: 'BATCH-M2', expiryDays: 25);
    }
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.textContaining('BATCH-M1'));
    await waitFor(tester, find.textContaining('BATCH-M2'));
  });

  await step(tester, '1.2.3-1.2.4 expired batch and asset item are not receivable', () async {
    await open(tester, InventoryRoutes.inventoryReceive);
    await tapLabel(tester, 'Add item');
    await waitFor(tester, find.textContaining('PEN-BLU-01'));
    expect(find.textContaining('LAP-DELL-15'), findsNothing); // 1.2.4
    await tapContaining(tester, 'Pasteurized Milk');
    await tapText(tester, 'Expiry date');
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    String two(int n) => n.toString().padLeft(2, '0');
    await tester.enterText(find.byType(TextField).last, '${two(yesterday.month)}/${two(yesterday.day)}/${yesterday.year}');
    await tapText(tester, 'OK');
    await waitFor(tester, find.text('Out of range.'));
    await back(tester);
  });

  Future<void> newRequest(String purpose, String destination, String item, String quantity) async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapLabel(tester, 'New Request');
    await tapText(tester, 'Issue from store');
    await tapText(tester, 'Central Main Store', index: 1);
    await fill(tester, 'Purpose', purpose);
    await fill(tester, 'Destination / Department (optional)', destination);
    await tapLabel(tester, 'Add item');
    await tapContaining(tester, item);
    await enter(tester, fieldStarting('Quantity'), quantity);
    await tapText(tester, 'Submit Request');
  }

  await step(tester, '1.2.5 create issue request', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await waitFor(tester, find.textContaining(RegExp(r'\d+ requests?|No issue requests')));
    if (await appears(tester, find.textContaining('Exam Hall Supplies for Midterms'))) return;
    await newRequest('Exam Hall Supplies for Midterms', 'Main Exam Hall - Block A', 'Ballpoint Pen', '30');
    await waitFor(tester, find.textContaining('ISR/'));
  });

  await step(tester, '1.2.6 approve issue request (over-approval blocked)', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Exam Hall Supplies for Midterms');
    if (!await appears(tester, find.text('Approve'))) return;
    await enter(tester, fieldStarting('Approve quantity'), '31');
    await tapText(tester, 'Approve');
    await waitFor(tester, find.textContaining('cannot approve more than'));
    await enter(tester, fieldStarting('Approve quantity'), '30');
    await tapText(tester, 'Approve');
    await waitFor(tester, find.textContaining('Approved 30'));
  });

  await step(tester, '1.2.7 rejection needs a reason', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await waitFor(tester, find.textContaining(RegExp(r'\d+ requests?')));
    if (!await appears(tester, find.textContaining('Rejection test request'))) {
      await newRequest('Rejection test request', 'Staff Room', 'Ballpoint Pen', '10');
    }
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Rejection test request');
    if (!await appears(tester, find.text('Reject'))) return;
    await tapText(tester, 'Reject');
    await tapText(tester, 'Reject', index: 1);
    await waitFor(tester, find.text('A reason is required'));
    await fill(tester, 'Reason', 'Department monthly quota exceeded');
    await tapText(tester, 'Reject', index: 1);
    await waitFor(tester, find.textContaining('Department monthly quota exceeded'));
  });

  await step(tester, '1.2.8 issue stock to the requester', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Exam Hall Supplies for Midterms');
    if (await appears(tester, find.textContaining('Remaining 30 of 30 approved'))) {
      await waitFor(tester, find.textContaining('requester'));
      await tapText(tester, 'Issue stock', index: 1);
    }
    await waitFor(tester, find.textContaining('ISS/'));
  });

  await step(tester, '1.2.9 over-balance request cannot be approved', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await waitFor(tester, find.textContaining(RegExp(r'\d+ requests?')));
    if (!await appears(tester, find.textContaining('Over balance test'))) {
      await newRequest('Over balance test', 'Store Yard', 'Ballpoint Pen', '500');
    }
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Over balance test');
    await tapText(tester, 'Approve');
    await waitFor(tester, find.textContaining('exceeds available stock'));
  });

  await step(tester, '1.2.10 confirm receipt', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Exam Hall Supplies for Midterms');
    if (await appears(tester, find.text('Confirm receipt'))) {
      await tapText(tester, 'Confirm receipt');
      await tapText(tester, 'Confirm');
    }
    await waitFor(tester, find.textContaining('Receipt confirmed'));
  });

  await step(tester, '1.2.11-1.2.12 return with a damaged split', () async {
    await open(tester, InventoryRoutes.inventoryRequests);
    await tapContaining(tester, 'Exam Hall Supplies for Midterms');
    if (!await appears(tester, find.textContaining('returned 15'))) {
      await tapText(tester, 'Return items');
      await waitFor(tester, find.textContaining('30 to return'));
      await enter(tester, fieldStarting('Usable'), '10');
      await enter(tester, fieldStarting('Damaged'), '5');
      await tapText(tester, 'Record return');
      await waitFor(tester, find.textContaining('returned 15'));
    }
    await tapText(tester, 'Return items');
    await waitFor(tester, find.textContaining('15 to return'));
    await enter(tester, fieldStarting('Usable'), '20');
    await tapText(tester, 'Record return');
    await waitFor(tester, find.textContaining('only 15 can still be returned'));
    await back(tester);
  });

  await step(tester, '1.2.13-1.2.14 transfer request', () async {
    await open(tester, InventoryRoutes.inventoryTransfers);
    await waitFor(tester, find.textContaining(RegExp('All \\(\\d+\\)')));
    if (await appears(tester, find.textContaining('TRF/'))) return;
    await tapLabel(tester, 'New Transfer');
    await tapText(tester, 'Source Store (From)');
    await tapText(tester, 'Central Main Store', index: 1);
    await tapText(tester, 'Destination Store (To)');
    expect(find.text('Central Main Store'), findsOneWidget); // 1.2.14: source is not offered as destination
    await tapText(tester, 'Science Lab Store', index: 1);
    await fill(tester, 'Remarks / Notes (optional)', 'Transfer surplus stationery to science faculty');
    await tapLabel(tester, 'Add item');
    await tapContaining(tester, 'Ballpoint Pen');
    await enter(tester, fieldStarting('Quantity'), '20');
    await tapText(tester, 'Request Transfer');
    await waitFor(tester, find.textContaining('TRF/'));
  });

  await step(tester, '1.2.15 approve and dispatch the transfer', () async {
    await open(tester, InventoryRoutes.inventoryTransfers);
    await tapContaining(tester, 'TRF/');
    if (await appears(tester, find.text('Approve transfer'))) {
      await tapText(tester, 'Approve transfer');
      await tapText(tester, 'Approve');
    }
    if (await appears(tester, find.text('Dispatch transfer'))) {
      await tapText(tester, 'Dispatch transfer');
      await tapText(tester, 'Dispatch');
    }
    await open(tester, InventoryRoutes.inventoryTransfers);
    await waitFor(tester, find.textContaining(RegExp('In Transit|Received')));
  });

  await step(tester, '1.2.16 partial receipt with a shortfall', () async {
    await open(tester, InventoryRoutes.inventoryTransfers);
    await tapContaining(tester, 'TRF/');
    if (!await appears(tester, find.text('Confirm receipt'))) return;
    await fill(tester, 'Receive now', '25');
    await tapText(tester, 'Confirm receipt');
    await waitFor(tester, find.textContaining('Only 20'));
    await fill(tester, 'Receive now', '15');
    await tapContaining(tester, 'Close transfer after this receipt');
    await tapText(tester, 'Confirm receipt');
    await tapText(tester, 'Close transfer', index: 1);
    await waitFor(tester, find.textContaining('Shortfall 5'));
  });

  await step(tester, '1.2.17 stock adjustment', () async {
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.textContaining('PEN-BLU-01'));
    if (!await appears(tester, find.textContaining('60'))) return;
    await tapContaining(tester, 'PEN-BLU-01');
    await tapText(tester, 'Adjust quantity');
    await waitFor(tester, find.text('Currently 60 available'));
    await enter(tester, fieldStarting('Change'), '-3');
    await fill(tester, 'Note', 'Physical count audit discrepancy');
    await tapText(tester, 'Apply adjustment');
    await open(tester, InventoryRoutes.inventoryStock);
    await waitFor(tester, find.textContaining('57'));
  });
}
