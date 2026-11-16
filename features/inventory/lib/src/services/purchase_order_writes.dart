import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/src/services/procurement_support.dart';

/// Purchase orders: save, issue, revise, acknowledge, cancel, close (receiving is `ReceivingWrites`).
class PurchaseOrderWrites with ProcurementSupport {
  Future<Map<String, dynamic>> savePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final requestId = data['purchaseRequestId']! as String;
    final request = await loadOrderableRequest(requestId);
    final lines = asLines(data['lineItems']);
    if (lines.isEmpty) failWith('Add at least one item');
    requireUniqueLines(lines);
    var vendorId = data['vendorId'] as String?;
    List<Map<String, dynamic>>? quoted;
    final quotationId = data['quotationId'] as String?;
    if (quotationId != null) {
      final (reference: _, data: quotation) = await loadDocument(
        'inventoryQuotations',
        quotationId,
        'Quotation',
      );
      if (quotation['purchaseRequestId'] != requestId) {
        failWith('Quotation does not belong to this request');
      }
      if (quotation['selected'] != true) {
        failWith('Quotation is not the selected one');
      }
      vendorId = quotation['vendorId'] as String;
      quoted = asLines(quotation['lineItems']);
    }
    if (vendorId == null) failWith('Vendor is required');
    final vendor = (await (await branchReference(
      'inventoryVendors',
      vendorId,
    )).get()).data();
    if (vendor == null) failWith('Vendor not found');
    if (vendor['status'] != 'active') failWith('Vendor is inactive');
    final expectedDate = data['expectedDate']! as String;
    if (expectedDate.compareTo(todayDay) < 0) {
      failWith('Expected delivery date is in the past');
    }
    final requestLines = asLines(request['lineItems']);
    final storedLines = <Map<String, Object?>>[];
    for (final line in lines) {
      final quotedLine = quoted
          ?.where((candidate) => lineKey(candidate) == lineKey(line))
          .firstOrNull;
      if (quoted != null && quotedLine == null) {
        failWith('Order lines must be lines of the quotation');
      }
      final requestLine = requestLines
          .where((candidate) => lineKey(candidate) == lineKey(line))
          .firstOrNull;
      if (requestLine == null) {
        failWith('Order lines must be lines of the request');
      }
      final quantity = line['quantityOrdered']! as num;
      if (quantity <= 0) failWith('Quantity must be above zero');
      if (quantity >
          (requestLine['quantity']! as num) -
              (requestLine['quantityOrdered']! as num)) {
        failWith('Ordered quantity exceeds what the request still needs');
      }
      storedLines.add({
        'itemId': line['itemId'],
        'variantId': line['variantId'],
        'quantityOrdered': quantity,
        'quantityReceived': 0,
        'quantityAccepted': 0,
        'quantityRejected': 0,
        'unitPrice': quotedLine?['unitPrice'] ?? line['unitPrice'] ?? 0,
      });
    }
    final discount = (data['discount'] as num?) ?? 0;
    final tax = (data['tax'] as num?) ?? 0;
    final delivery = (data['delivery'] as num?) ?? 0;
    final totals = documentTotals(
      [
        for (final line in storedLines)
          {'quantity': line['quantityOrdered'], 'unitPrice': line['unitPrice']},
      ],
      discount: discount,
      tax: tax,
      delivery: delivery,
    );
    final fields = {
      'vendorId': vendorId,
      'quotationId': quotationId,
      'expectedDate': dayTimestamp(expectedDate),
      'terms': blankToNullText(data['terms']),
      'lineItems': storedLines,
      'discount': discount,
      'tax': tax,
      'delivery': delivery,
      'remarks': blankToNullText(data['remarks']),
      'subtotal': totals.subtotal,
      'total': totals.total,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await loadDocument(
        'inventoryPurchaseOrders',
        id,
        'Purchase order',
      );
      if (existing['status'] != 'draft') {
        failWith('Only draft orders can be edited');
      }
      if ((existing['purchaseRequestIds'] as List).first != requestId) {
        failWith('Request cannot change');
      }
      await reference.update({
        ...fields,
        'lastWrite': writeStamp('inventoryPurchaseOrder.update'),
      });
      return {'id': id, 'number': existing['number']};
    }
    final number = await nextNumber('PO');
    final reference = (await branchCollection('inventoryPurchaseOrders')).doc();
    await reference.set({
      ...fields,
      'number': number,
      'purchaseRequestIds': [requestId],
      'purchaseOrderDate': dayTimestamp(todayDay),
      'status': 'draft',
      'acknowledgement': null,
      'revision': 0,
      'lastWrite': writeStamp('inventoryPurchaseOrder.create'),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
    });
    return {'id': reference.id, 'number': number};
  }

  /// Issuing reserves the ordered quantity on the request (`quantityOrdered`) and
  /// sets its status to `partially_ordered` / `ordered`.
  Future<Map<String, dynamic>> issuePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final orderRef = await branchReference(
      'inventoryPurchaseOrders',
      data['id']! as String,
    );
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final order = (await transaction.get(orderRef)).data();
      if (order == null) failWith('Purchase order not found');
      if (order['status'] != 'draft') failWith('Order is ${order['status']}');
      final requestRef = await branchReference(
        'inventoryPurchaseRequests',
        (order['purchaseRequestIds'] as List).first as String,
      );
      final request = (await transaction.get(requestRef)).data();
      if (request == null) failWith('Purchase request not found');
      if (!orderablePurchaseRequestStatuses.contains(request['status'])) {
        failWith('Request is ${request['status']}; it must be approved');
      }
      final vendor = (await transaction.get(
        await branchReference('inventoryVendors', order['vendorId'] as String),
      )).data();
      if (vendor == null) failWith('Vendor not found');
      if (vendor['status'] != 'active') failWith('Vendor is inactive');
      final orderLines = asLines(order['lineItems']);
      final requestLines = asLines(request['lineItems']);
      for (final requestLine in requestLines) {
        final orderLine = orderLines
            .where((line) => lineKey(line) == lineKey(requestLine))
            .firstOrNull;
        if (orderLine == null) continue;
        final quantity = orderLine['quantityOrdered']! as num;
        final ordered = requestLine['quantityOrdered']! as num;
        if (quantity > (requestLine['quantity']! as num) - ordered) {
          failWith('Ordered quantity exceeds what the request still needs');
        }
        requestLine['quantityOrdered'] = ordered + quantity;
      }
      for (final orderLine in orderLines) {
        if (!requestLines.any((line) => lineKey(line) == lineKey(orderLine))) {
          failWith('Order lines must be lines of the request');
        }
      }
      final allOrdered = requestLines.every(
        (line) =>
            (line['quantityOrdered']! as num) >= (line['quantity']! as num),
      );
      final anyOrdered = requestLines.any(
        (line) => (line['quantityOrdered']! as num) > 0,
      );
      transaction
        ..update(requestRef, {
          'lineItems': requestLines,
          'status': allOrdered
              ? 'ordered'
              : anyOrdered
              ? 'partially_ordered'
              : 'approved',
          'lastWrite': writeStamp('inventoryPurchaseRequest.order'),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..update(orderRef, {
          'status': 'issued',
          'issuedAt': FieldValue.serverTimestamp(),
          'issuedBy': currentUid,
          'lastWrite': writeStamp('inventoryPurchaseOrder.issue'),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
    return {'id': orderRef.id};
  }

  /// Post-issue change: expected date, unit prices and (reason required) a
  /// `revisions` snapshot of the previous version; resets the acknowledgement.
  Future<Map<String, dynamic>> revisePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final reason = blankToNullText(data['reason']);
    if (reason == null) failWith('A reason is required');
    final orderRef = await branchReference(
      'inventoryPurchaseOrders',
      data['id']! as String,
    );
    final prices = asLines((data['prices'] as List?) ?? const []);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final order = (await transaction.get(orderRef)).data();
      if (order == null) failWith('Purchase order not found');
      if (!['issued', 'acknowledged'].contains(order['status'])) {
        failWith('Order is ${order['status']}');
      }
      final lines = asLines(order['lineItems']);
      for (final price in prices) {
        final line = lines
            .where((candidate) => lineKey(candidate) == lineKey(price))
            .firstOrNull;
        if (line == null) failWith('Price given for an item not on the order');
        line['unitPrice'] = price['unitPrice'];
      }
      final discount = (data['discount'] as num?) ?? order['discount'] as num;
      final tax = (data['tax'] as num?) ?? order['tax'] as num;
      final delivery = (data['delivery'] as num?) ?? order['delivery'] as num;
      final totals = documentTotals(
        [
          for (final line in lines)
            {
              'quantity': line['quantityOrdered'],
              'unitPrice': line['unitPrice'],
            },
        ],
        discount: discount,
        tax: tax,
        delivery: delivery,
      );
      final expectedDate = data['expectedDate'] as String?;
      transaction
        ..set(orderRef.collection('revisions').doc(), {
          'snapshot': order,
          'changedBy': currentUid,
          'reason': reason,
          'performedAt': FieldValue.serverTimestamp(),
        })
        ..update(orderRef, {
          'lineItems': lines,
          'discount': discount,
          'tax': tax,
          'delivery': delivery,
          'subtotal': totals.subtotal,
          'total': totals.total,
          'expectedDate': expectedDate == null
              ? order['expectedDate']
              : dayTimestamp(expectedDate),
          'revision': (order['revision'] as num) + 1,
          'status': 'issued',
          'acknowledgement': null,
          'lastWrite': writeStamp('inventoryPurchaseOrder.revise', reason),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      return {'id': orderRef.id, 'number': order['number']};
    });
  }

  Future<Map<String, dynamic>> acknowledgePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: order) = await loadDocument(
      'inventoryPurchaseOrders',
      data['id']! as String,
      'Purchase order',
    );
    if (order['status'] != 'issued') failWith('Order is ${order['status']}');
    await reference.update({
      'status': 'acknowledged',
      'acknowledgement': {
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'vendorRef': blankToNullText(data['vendorRef']),
        'remarks': blankToNullText(data['remarks']),
      },
      'lastWrite': writeStamp('inventoryPurchaseOrder.acknowledge'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': order['number']};
  }

  /// Cancel (nothing received yet) or close an order. Either gives the quantity it
  /// still holds on the request back (a draft holds none), so a new order can cover it;
  /// closing needs a reason unless fully received.
  Future<Map<String, dynamic>> endPurchaseOrder(
    Map<String, Object?> data, {
    required bool cancel,
  }) async {
    final reason = blankToNullText(data['reason']);
    // A fully received order closes without a reason; checked once the status is known.
    final orderRef = await branchReference(
      'inventoryPurchaseOrders',
      data['id']! as String,
    );
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final order = (await transaction.get(orderRef)).data();
      if (order == null) failWith('Purchase order not found');
      final status = order['status'];
      if (!(cancel
              ? ['draft', 'issued', 'acknowledged']
              : [
                  'issued',
                  'acknowledged',
                  'partially_received',
                  'fully_received',
                ])
          .contains(status)) {
        failWith('Order is $status');
      }
      if (reason == null && (cancel || status != 'fully_received')) {
        failWith(
          cancel ? 'A reason is required' : 'A reason is required to close an order that is not fully received',
        );
      }
      final holdsQuantity = cancel
          ? status != 'draft'
          : status != 'fully_received';
      final requestRef = await branchReference(
        'inventoryPurchaseRequests',
        (order['purchaseRequestIds'] as List).first as String,
      );
      final request = holdsQuantity
          ? (await transaction.get(requestRef)).data()
          : null;
      if (request != null) {
        final released = asLines(order['lineItems']);
        final requestLines = asLines(request['lineItems']);
        for (final requestLine in requestLines) {
          final line = released
              .where((candidate) => lineKey(candidate) == lineKey(requestLine))
              .firstOrNull;
          if (line == null) continue;
          // Closing releases only what was not accepted; cancelling, everything.
          final quantity = cancel
              ? line['quantityOrdered']! as num
              : ((line['quantityOrdered']! as num) -
                        (line['quantityAccepted']! as num))
                    .clamp(0, double.infinity);
          requestLine['quantityOrdered'] =
              ((requestLine['quantityOrdered']! as num) - quantity).clamp(
                0,
                double.infinity,
              );
        }
        final allOrdered = requestLines.every(
          (line) =>
              (line['quantityOrdered']! as num) >= (line['quantity']! as num),
        );
        final anyOrdered = requestLines.any(
          (line) => (line['quantityOrdered']! as num) > 0,
        );
        transaction.update(requestRef, {
          'lineItems': requestLines,
          'status': allOrdered
              ? 'ordered'
              : anyOrdered
              ? 'partially_ordered'
              : 'approved',
          'lastWrite': writeStamp('inventoryPurchaseRequest.order'),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(orderRef, {
        'status': cancel ? 'cancelled' : 'closed',
        cancel ? 'cancelReason' : 'closeReason': reason,
        'lastWrite': writeStamp(
          cancel
              ? 'inventoryPurchaseOrder.cancel'
              : 'inventoryPurchaseOrder.close',
          reason,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return {'id': orderRef.id, 'number': order['number']};
    });
  }
}
