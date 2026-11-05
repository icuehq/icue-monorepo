import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

import '../support/driver.dart';

/// Guide 1.3 (procurement). Steps run once: each is skipped when its outcome is already on screen.
Future<void> procurementSteps(WidgetTester tester) async {
  Future<void> fillStarting(String prefix, String value, {int index = 0}) =>
      enter(tester, fieldStarting(prefix, index: index), value);

  Future<void> addVendor({
    required String name,
    required String contact,
    required String phone,
    required String email,
    String gst = '',
    String address = '',
    String remarks = '',
  }) async {
    await tapLabel(tester, 'New vendor');
    await fill(tester, 'Vendor name *', name);
    await fill(tester, 'Contact person', contact);
    await fill(tester, 'Phone', phone);
    await fill(tester, 'Email', email);
    if (gst.isNotEmpty) await fill(tester, 'GST / Tax ID', gst);
    if (address.isNotEmpty) await fill(tester, 'Address', address);
    if (remarks.isNotEmpty) await fill(tester, 'Remarks (optional)', remarks);
    await tapText(tester, 'Stationery');
    await tapText(tester, 'Save vendor');
  }

  await step(tester, '1.3.1-1.3.3 vendors and validation', () async {
    await open(tester, InventoryRoutes.inventoryVendors);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (!await appears(tester, find.textContaining('Apex Educational'))) {
      await addVendor(
        name: 'Apex Educational Supplies Ltd.',
        contact: 'Sunil Verma',
        phone: '9876543210',
        email: 'sales@apexsupplies.com',
        gst: '29ABCDE1234F1Z5',
        address: 'Plot 14, Industrial Estate, Bangalore',
        remarks: 'Payment terms: Net 30 days',
      );
      await waitFor(tester, find.textContaining('Apex Educational'));
    }
    if (!await appears(tester, find.textContaining('Global Tech'))) {
      await addVendor(name: 'Global Tech & Lab Instruments', contact: 'Priya Nair', phone: '9845012345', email: 'orders@globaltechlab.in');
      await waitFor(tester, find.textContaining('Global Tech'));
    }
    await tapLabel(tester, 'New vendor');
    await fill(tester, 'Vendor name *', 'Bad Vendor');
    await fill(tester, 'Phone', '12');
    await fill(tester, 'Email', 'abc');
    await tapText(tester, 'Save vendor');
    await waitFor(tester, find.text('Enter a valid email address'));
    await waitFor(tester, find.text('Enter a valid phone number'));
    await back(tester);
  });

  await step(tester, '1.3.4 purchase request draft', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseRequests);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (await appears(tester, find.textContaining('PR/'))) return;
    await tapLabel(tester, 'New Request');
    await tapText(tester, 'Priority');
    await tapText(tester, 'High', index: 1);
    await fillStarting('Purpose', 'Annual Examination & Office Supplies Requisition');
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
    if (await appears(tester, find.text('Submit'))) await tapText(tester, 'Submit');
    await waitFor(tester, find.textContaining('Pending'));
  });

  await step(tester, '1.3.8 return needs a comment', () async {
    await openPurchaseRequest();
    if (!await appears(tester, find.text('Return'))) return;
    await tapText(tester, 'Return');
    await tapText(tester, 'Return', index: 1);
    await waitFor(tester, find.text('A comment is required'));
    await fillStarting('Comment', 'Please reduce laptop quantity from 5 to 2 due to quarterly budget ceiling.');
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
    await waitFor(tester, find.text('Quotations'));
    await waitFor(tester, find.text('Direct PO'));
  });

  Future<void> addQuotation(String vendor, String ref, int validDays, String lead, String pen, String laptop) async {
    await tapLabel(tester, 'New Quotation');
    await tapText(tester, 'Select Vendor *');
    await tapContaining(tester, vendor, index: 1);
    await fillStarting("Vendor's quotation", ref);
    await pickDate(tester, 'Valid Until *', validDays);
    await fillStarting('Lead time', lead);
    await enter(tester, fieldStarting('Unit price'), pen);
    await enter(tester, fieldStarting('Unit price', index: 1), laptop);
    await tapText(tester, 'Record Quotation');
  }

  await step(tester, '1.3.11-1.3.12 record two quotations', () async {
    await openPurchaseRequest();
    await tapText(tester, 'Quotations');
    await waitFor(tester, find.textContaining('Quotations'));
    if (!await appears(tester, find.textContaining('QT-APEX-2026-09'))) {
      await addQuotation('Apex Educational', 'QT-APEX-2026-09', 30, '5', '14.50', '54000');
      await waitFor(tester, find.textContaining('QT-APEX-2026-09'));
    }
    if (!await appears(tester, find.textContaining('QT-GLB-881'))) {
      await addQuotation('Global Tech', 'QT-GLB-881', 15, '12', '15.50', '53500');
      await waitFor(tester, find.textContaining('QT-GLB-881'));
    }
    await waitFor(tester, find.text('Price Comparison Table'));
    await waitFor(tester, find.text('Lowest Quote'));
  });

  await step(tester, '1.3.13 select a quote with a reason', () async {
    await openPurchaseRequest();
    await tapText(tester, 'Quotations');
    if (await appears(tester, find.text('SELECTED'))) return;
    await tapNear(tester, find.textContaining('QT-APEX-2026-09'), find.text('Select this Quote'));
    await tapText(tester, 'Select Quotation');
    await waitFor(tester, find.text('A reason is required'));
    await fillStarting('Selection reason', 'Shorter lead time of 5 days and local support warranty.');
    await tapText(tester, 'Select Quotation');
    await waitFor(tester, find.text('SELECTED'));
    await waitFor(tester, find.text('Create PO from Quote'));
  });

  await step(tester, '1.3.14 create PO from the selected quote', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (await appears(tester, find.textContaining('PO/'))) return;
    await openPurchaseRequest();
    await tapText(tester, 'Quotations');
    await tapText(tester, 'Create PO from Quote');
    await fillStarting('Tax', '19701');
    await pickDate(tester, 'Expected Delivery Date *', 7);
    await fillStarting('Terms and conditions', 'Door delivery to Central Main Store');
    await tapText(tester, 'Save Draft PO');
    await waitFor(tester, find.textContaining('PO/'));
  });

  Future<void> openPurchaseOrder() async {
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await tapContaining(tester, 'PO/');
  }

  await step(tester, '1.3.15 issue and acknowledge the PO', () async {
    await openPurchaseOrder();
    if (await appears(tester, find.text('Issue PO'))) {
      await tapText(tester, 'Issue PO');
      await openPurchaseOrder();
    }
    if (await appears(tester, find.text('Confirm Vendor Acknowledged'))) {
      await tapText(tester, 'Confirm Vendor Acknowledged');
    }
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('Acknowledged'));
  });

  await step(tester, '1.3.17 revise the PO and re-acknowledge', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('PO/'));
    if (!await appears(tester, find.text('Rev 1'))) {
      await tapContaining(tester, 'PO/');
      await tapText(tester, 'Revise PO');
      await enter(tester, fieldStarting('Ballpoint Pen'), '14');
      await fillStarting('Revision reason', 'Negotiated educational volume discount on pens');
      await tapText(tester, 'Save Revision');
    }
    await openPurchaseOrder();
    if (await appears(tester, find.text('Confirm Vendor Acknowledged'))) {
      await tapText(tester, 'Confirm Vendor Acknowledged');
    }
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.text('Rev 1'));
  });

  await step(tester, '1.3.18 partial goods receiving', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('PO/'));
    if (!await appears(tester, find.textContaining('0% received'))) return;
    await tapContaining(tester, 'PO/');
    await tapContaining(tester, 'Receive Goods');
    await tapText(tester, 'Store');
    await tapText(tester, 'Central Main Store', index: 1);
    await fillStarting('Delivery note', 'DC-APEX-7741');
    await enter(tester, fieldStarting('Accepted'), '80');
    await enter(tester, fieldStarting('Rejected'), '5');
    await enter(tester, fieldStarting('Condition'), '5 broken tips during transit');
    await fillStarting('Overall inspection remarks', 'First consignment received; 5 pens rejected at inspection.');
    await tapContaining(tester, 'Confirm receiving');
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('Partially Received'));
  });

  await step(tester, '1.3.19-1.3.20 over-due refused, accept all due', () async {
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('PO/'));
    if (!await appears(tester, find.textContaining('Partially Received'))) return;
    await tapContaining(tester, 'PO/');
    await tapContaining(tester, 'Receive Goods');
    await tapText(tester, 'Store');
    await tapText(tester, 'Central Main Store', index: 1);
    await enter(tester, fieldStarting('Accepted'), '25');
    await tapContaining(tester, 'Confirm receiving');
    await waitFor(tester, find.text('Only 20 due'));
    await tapText(tester, 'Clear quantities');
    await tapText(tester, 'Accept all due');
    await fillStarting('Delivery note', 'DC-APEX-7742');
    await tapContaining(tester, 'Confirm receiving');
    await open(tester, InventoryRoutes.inventoryPurchaseOrders);
    await waitFor(tester, find.textContaining('Fully Received'));
  });

  Future<void> recordInvoice(String number) async {
    await openPurchaseOrder();
    await tapText(tester, 'Record Invoice');
    await fillStarting('Vendor Invoice Number', number);
    await pickDate(tester, 'Due Date *', 30);
    await tapContaining(tester, 'DC-APEX-7741');
    await tapContaining(tester, 'DC-APEX-7742');
    await tapText(tester, 'Record Invoice', index: 1);
  }

  await step(tester, '1.3.21-1.3.22 record invoice, duplicate refused', () async {
    await open(tester, InventoryRoutes.inventoryInvoices);
    await waitFor(tester, find.textContaining(RegExp(r'All \(\d+\)')));
    if (!await appears(tester, find.textContaining('INV-APEX-2026-104'))) {
      await recordInvoice('INV-APEX-2026-104');
      await open(tester, InventoryRoutes.inventoryInvoices);
      await waitFor(tester, find.textContaining('INV-APEX-2026-104'));
    }
    await recordInvoice('INV-APEX-2026-104');
    await waitFor(tester, find.textContaining('already exists'));
    await back(tester);
  });

  await step(tester, '1.3.23 payment status transitions', () async {
    await open(tester, InventoryRoutes.inventoryInvoices);
    await tapContaining(tester, 'INV-APEX-2026-104');
    if (await appears(tester, find.text('Unpaid'))) {
      await tapText(tester, 'Update Payment Status');
      await fillStarting('Total paid amount', '50000');
      await tapText(tester, 'Confirm');
      await open(tester, InventoryRoutes.inventoryInvoices);
      await tapContaining(tester, 'INV-APEX-2026-104');
    }
    if (await appears(tester, find.textContaining('Partially'))) {
      await tapText(tester, 'Update Payment Status');
      await fillStarting('Total paid amount', '200000');
      await tapText(tester, 'Confirm');
      await waitFor(tester, find.textContaining('exceeds the invoice total'));
      if (await appears(tester, find.text('Update Payment Status'))) await tapText(tester, 'Update Payment Status');
      await fillStarting('Total paid amount', '129101');
      await tapText(tester, 'Confirm');
    }
    await open(tester, InventoryRoutes.inventoryInvoices);
    await waitFor(tester, find.text('Paid'));
  });

  await step(tester, '1.3.24 cancellation safeguards', () async {
    await open(tester, InventoryRoutes.inventoryInvoices);
    await tapContaining(tester, 'INV-APEX-2026-104');
    await waitFor(tester, find.text('Update Payment Status'));
    expect(find.text('Cancel Invoice'), findsNothing); // a Paid invoice offers no cancel
    await open(tester, InventoryRoutes.inventoryInvoices);
    if (!await appears(tester, find.textContaining('INV-APEX-2026-105'))) {
      await recordInvoice('INV-APEX-2026-105');
      await open(tester, InventoryRoutes.inventoryInvoices);
    }
    await tapContaining(tester, 'INV-APEX-2026-105');
    if (await appears(tester, find.text('Cancel Invoice'))) {
      await tapText(tester, 'Cancel Invoice');
      await tapText(tester, 'Confirm');
      await waitFor(tester, find.textContaining('reason'));
      await tapText(tester, 'Cancel Invoice');
      await fillStarting('Cancellation reason', 'Entered in error');
      await tapText(tester, 'Confirm');
    }
    await open(tester, InventoryRoutes.inventoryInvoices);
    await waitFor(tester, find.textContaining('Cancelled'));
  });
}
