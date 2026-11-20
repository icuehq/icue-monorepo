import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/src/services/procurement_support.dart';

/// Vendor invoices: save, payment, cancel.
class InvoiceWrites with ProcurementSupport {
  double _invoiceTotal(num subtotal, num tax, num discount) {
    if (discount > subtotal) failWith('Discount exceeds the subtotal');
    return roundToCents(subtotal - discount + tax);
  }

  Future<Map<String, dynamic>> saveInvoice(Map<String, Object?> data) async {
    final orderId = data['purchaseOrderId']! as String;
    final (reference: _, data: order) = await loadDocument(
      'inventoryPurchaseOrders',
      orderId,
      'Purchase order',
    );
    if (['draft', 'cancelled'].contains(order['status'])) {
      failWith('Order is ${order['status']}');
    }
    final invoiceDate = data['invoiceDate']! as String;
    final dueDate = blankToNullText(data['dueDate']);
    if (invoiceDate.compareTo(todayDay) > 0) {
      failWith('Invoice date is in the future');
    }
    if (dueDate != null && dueDate.compareTo(invoiceDate) < 0) {
      failWith('Due date is before the invoice date');
    }
    final receiptIds = [...((data['receiptIds'] as List?) ?? [])];
    for (final receiptId in receiptIds) {
      final receipt = (await (await branchReference(
        'inventoryReceipts',
        receiptId as String,
      )).get()).data();
      if (receipt?['purchaseOrderId'] != orderId) {
        failWith('Receiving reference does not belong to this order');
      }
    }
    final total = _invoiceTotal(
      data['subtotal']! as num,
      data['tax']! as num,
      data['discount']! as num,
    );
    final fields = {
      'invoiceDate': dayTimestamp(invoiceDate),
      'dueDate': dayTimestampOrNull(dueDate),
      'receiptIds': receiptIds,
      'subtotal': data['subtotal'],
      'tax': data['tax'],
      'discount': data['discount'],
      'total': total,
      'outstanding': total,
      'remarks': blankToNullText(data['remarks']),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await loadDocument(
        'inventoryInvoices',
        id,
        'Invoice',
      );
      if (existing['paymentStatus'] != 'unpaid') {
        failWith('Invoice is ${existing['paymentStatus']}');
      }
      await reference.update({
        ...fields,
        'lastWrite': writeStamp('inventoryInvoice.update'),
      });
      return {'id': id};
    }
    final invoiceNumber = (data['invoiceNumber']! as String).trim();
    final duplicates = await (await branchCollection('inventoryInvoices'))
        .where('vendorId', isEqualTo: order['vendorId'])
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .get();
    if (duplicates.docs.any(
      (duplicate) => duplicate.data()['paymentStatus'] != 'cancelled',
    )) {
      failWith('Invoice "$invoiceNumber" already exists for this vendor');
    }
    final reference = (await branchCollection('inventoryInvoices')).doc();
    await reference.set({
      ...fields,
      'vendorId': order['vendorId'],
      'purchaseOrderId': orderId,
      'purchaseOrderNumber': order['number'],
      'invoiceNumber': invoiceNumber,
      'paymentStatus': 'unpaid',
      'paidAmount': 0,
      'payment': null,
      'attachments': <Object?>[],
      'lastWrite': writeStamp('inventoryInvoice.create'),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
    });
    return {'id': reference.id};
  }

  Future<Map<String, dynamic>> setInvoicePayment(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: invoice) = await loadDocument(
      'inventoryInvoices',
      data['id']! as String,
      'Invoice',
    );
    if (invoice['paymentStatus'] == 'cancelled') {
      failWith('Invoice is cancelled');
    }
    final paidAmount = data['paidAmount']! as num;
    final total = invoice['total'] as num;
    if (paidAmount < 0) failWith('Invalid paid amount');
    if (paidAmount > total) failWith('Paid amount exceeds the invoice total');
    final paymentStatus = paidAmount >= total
        ? 'paid'
        : paidAmount > 0
        ? 'partially_paid'
        : 'unpaid';
    await reference.update({
      'paidAmount': paidAmount,
      'outstanding': roundToCents(total - paidAmount),
      'paymentStatus': paymentStatus,
      'payment': {
        'reference': blankToNullText(data['reference']),
        'date': dayTimestamp((data['paidDate'] as String?) ?? todayDay),
        'performedBy': currentUid,
      },
      // Every update is kept: `amount` is what this entry added (negative for a correction).
      'payments': FieldValue.arrayUnion([
        {
          'amount': roundToCents(
            paidAmount - ((invoice['paidAmount'] as num?) ?? 0),
          ),
          'paidAmount': paidAmount,
          'reference': blankToNullText(data['reference']),
          'date': dayTimestamp((data['paidDate'] as String?) ?? todayDay),
          'performedBy': currentUid,
        },
      ]),
      'lastWrite': writeStamp('inventoryInvoice.payment'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'paymentStatus': paymentStatus};
  }

  Future<Map<String, dynamic>> cancelInvoice(Map<String, Object?> data) async {
    final (:reference, data: invoice) = await loadDocument(
      'inventoryInvoices',
      data['id']! as String,
      'Invoice',
    );
    if (invoice['paymentStatus'] != 'unpaid') {
      failWith('Invoice is ${invoice['paymentStatus']}');
    }
    final reason = blankToNullText(data['reason']);
    if (reason == null) failWith('A reason is required');
    await reference.update({
      'paymentStatus': 'cancelled',
      'cancelReason': reason,
      'lastWrite': writeStamp('inventoryInvoice.cancel', reason),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id};
  }
}
