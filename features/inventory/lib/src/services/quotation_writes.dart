import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/src/services/procurement_support.dart';

/// Quotations: save and select.
class QuotationWrites with ProcurementSupport {
  Future<Map<String, dynamic>> saveQuotation(Map<String, Object?> data) async {
    final requestId = data['purchaseRequestId']! as String;
    final request = await loadOrderableRequest(requestId);
    final vendorId = data['vendorId']! as String;
    final vendor = (await (await branchReference(
      'inventoryVendors',
      vendorId,
    )).get()).data();
    if (vendor == null) failWith('Vendor not found');
    if (vendor['status'] != 'active') failWith('Vendor is inactive');
    final lines = asLines(data['lineItems']);
    requireUniqueLines(lines);
    final requestLines = asLines(request['lineItems']);
    for (final line in lines) {
      final requestLine = requestLines
          .where((candidate) => lineKey(candidate) == lineKey(line))
          .firstOrNull;
      if (requestLine == null) {
        failWith('Quotation lines must be lines of the request');
      }
      if ((line['quantity']! as num) > (requestLine['quantity']! as num)) {
        failWith('Quoted quantity exceeds the requested quantity');
      }
    }
    final date = (data['quotationDate'] as String?) ?? todayDay;
    final validUntil = data['validUntil']! as String;
    if (validUntil.compareTo(date) < 0) {
      failWith('Valid until is before the quotation date');
    }
    final discount = (data['discount'] as num?) ?? 0;
    final tax = (data['tax'] as num?) ?? 0;
    final delivery = (data['delivery'] as num?) ?? 0;
    final storedLines = [
      for (final line in lines)
        {
          'itemId': line['itemId'],
          'variantId': line['variantId'],
          'quantity': line['quantity'],
          'unitPrice': line['unitPrice'],
        },
    ];
    final totals = documentTotals(
      storedLines,
      discount: discount,
      tax: tax,
      delivery: delivery,
    );
    final fields = {
      'vendorId': vendorId,
      'vendorRef': blankToNullText(data['vendorRef']),
      'quotationDate': dayTimestamp(date),
      'validUntil': dayTimestamp(validUntil),
      'deliveryDays': data['deliveryDays'],
      'lineItems': storedLines,
      'discount': discount,
      'tax': tax,
      'delivery': delivery,
      'remarks': blankToNullText(data['remarks']),
      'subtotal': totals.subtotal,
      'total': totals.total,
      'status': data['final'] == true ? 'final' : 'draft',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await loadDocument(
        'inventoryQuotations',
        id,
        'Quotation',
      );
      if (existing['status'] != 'draft') {
        failWith('Only draft quotations can be edited');
      }
      await reference.update({
        ...fields,
        'lastWrite': writeStamp('inventoryQuotation.update'),
      });
      return {'id': id, 'number': existing['number']};
    }
    final number = await nextNumber('QT');
    final reference = (await branchCollection('inventoryQuotations')).doc();
    await reference.set({
      ...fields,
      'number': number,
      'purchaseRequestId': requestId,
      'selected': false,
      'selectionReason': null,
      'attachments': <Object?>[],
      'lastWrite': writeStamp('inventoryQuotation.create'),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
    });
    return {'id': reference.id, 'number': number};
  }

  Future<Map<String, dynamic>> selectQuotation(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: quotation) = await loadDocument(
      'inventoryQuotations',
      data['id']! as String,
      'Quotation',
    );
    await loadOrderableRequest(quotation['purchaseRequestId'] as String);
    if (quotation['status'] != 'final') {
      failWith('Only final quotations can be selected');
    }
    if (readDay(quotation['validUntil']).compareTo(todayDay) < 0) {
      failWith('Quotation has expired');
    }
    final siblings = await (await branchCollection('inventoryQuotations'))
        .where('purchaseRequestId', isEqualTo: quotation['purchaseRequestId'])
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final sibling in siblings.docs) {
      if (sibling.id == reference.id || sibling.data()['selected'] != true) {
        continue;
      }
      final orders = await (await branchCollection('inventoryPurchaseOrders'))
          .where('quotationId', isEqualTo: sibling.id)
          .get();
      if (orders.docs.any((order) => order.data()['status'] != 'cancelled')) {
        failWith('A purchase order already uses the selected quotation');
      }
      batch.update(sibling.reference, {
        'selected': false,
        'selectionReason': null,
        'lastWrite': writeStamp('inventoryQuotation.deselect'),
      });
    }
    batch.update(reference, {
      'selected': true,
      'selectionReason': (data['reason']! as String).trim(),
      'lastWrite': writeStamp(
        'inventoryQuotation.select',
        (data['reason']! as String).trim(),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {'id': reference.id, 'number': quotation['number']};
  }
}
