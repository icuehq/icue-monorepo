import 'package:core_ui/core_ui.dart';
import 'package:icue_firebase/icue_firebase.dart';

/// Client-side purchase request, quotation and invoice writes.
///
/// Business checks live here, not in `firestore.rules`. There is no audit log,
/// no approver notification, no campus check, and no re-validation of items,
/// variants or unit consistency.
class ProcurementWrites {
  /// Action names `ProcurementProvider.act` routes here instead of to a callable.
  static const names = {
    'inventory-purchaseRequest-save',
    'inventory-purchaseRequest-submit',
    'inventory-purchaseRequest-decide',
    'inventory-purchaseRequest-cancel',
    'inventory-quotation-save',
    'inventory-quotation-select',
    'inventory-invoice-save',
    'inventory-invoice-setPayment',
    'inventory-invoice-cancel',
  };

  Future<Map<String, dynamic>> run(String name, Map<String, Object?> data) =>
      switch (name) {
        'inventory-purchaseRequest-save' => _savePurchaseRequest(data),
        'inventory-purchaseRequest-submit' => _submitPurchaseRequest(data),
        'inventory-purchaseRequest-decide' => _decidePurchaseRequest(data),
        'inventory-purchaseRequest-cancel' => _cancelPurchaseRequest(data),
        'inventory-quotation-save' => _saveQuotation(data),
        'inventory-quotation-select' => _selectQuotation(data),
        'inventory-invoice-save' => _saveInvoice(data),
        'inventory-invoice-setPayment' => _setInvoicePayment(data),
        'inventory-invoice-cancel' => _cancelInvoice(data),
        _ => throw ArgumentError.value(name, 'name'),
      };

  // --- shared helpers ------------------------------------------------------

  Never _fail(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  String get _today => todayIST();

  double _roundToCents(num amount) => (amount * 100).round() / 100;

  Map<String, Object?> _historyEntry(String action, [String? comment]) => {
    'action': action,
    'performedBy': _uid,
    'performedAt': Timestamp.now(),
    'comment': comment,
  };

  String? _blankToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<DocumentReference<Map<String, dynamic>>> _reference(
    String collection,
    String id,
  ) async => (await schoolCollection(collection)).doc(id);

  Future<
    ({
      DocumentReference<Map<String, dynamic>> reference,
      Map<String, dynamic> data,
    })
  >
  _load(String collection, String id, String label) async {
    final reference = await _reference(collection, id);
    final data = (await reference.get()).data();
    if (data == null) _fail('$label not found');
    return (reference: reference, data: data);
  }

  /// Next `TYPE/2026-27/000123`, from a counter document updated in a transaction.
  Future<String> _nextNumber(String type) async {
    final financialYear = DateTime.now().toIndianTime().financialYear;
    final counter = await _reference('counters', '${type}_$financialYear');
    final next = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final current =
          ((await transaction.get(counter)).data()?['next'] as num?) ?? 0;
      final value = current.toInt() + 1;
      transaction.set(counter, {
        'next': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return value;
    });
    return '$type/$financialYear/${next.toString().padLeft(6, '0')}';
  }

  void _requireUniqueLines(List<Map<String, dynamic>> lines) {
    final keys = {for (final line in lines) _lineKey(line)};
    if (keys.length != lines.length) {
      _fail('Each item (and variant) may appear once');
    }
  }

  String _lineKey(Map<String, dynamic> line) =>
      '${line['itemId']}__${line['variantId'] ?? '-'}';

  List<Map<String, dynamic>> _lines(Object? value) => [
    for (final line in (value! as List)) Map<String, dynamic>.from(line as Map),
  ];

  // --- purchase requests ---------------------------------------------------

  Future<Map<String, dynamic>> _savePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final requiredDate = data['requiredDate']! as String;
    if (requiredDate.compareTo(_today) < 0) {
      _fail('Required date is in the past');
    }
    final submit = data['submit'] == true;
    final lines = _lines(data['lineItems']);
    if (lines.isEmpty) _fail('Add at least one item');
    _requireUniqueLines(lines);
    final storedLines = [
      for (final line in lines)
        {
          'itemId': line['itemId'],
          'variantId': line['variantId'],
          'quantity': line['quantity'],
          'estimatedPrice': line['estimatedPrice'] ?? 0,
          'quantityOrdered': 0,
        },
    ];
    final fields = {
      'departmentId': data['departmentId'],
      'requiredDate': dayTimestamp(requiredDate),
      'priority': data['priority'] ?? 'normal',
      'purpose': (data['purpose']! as String).trim(),
      'remarks': _blankToNull(data['remarks']),
      'lineItems': storedLines,
      'itemIds': {for (final line in storedLines) line['itemId']}.toList(),
      'total': _roundToCents(
        storedLines.fold<double>(
          0,
          (total, line) =>
              total +
              (line['quantity']! as num) * (line['estimatedPrice']! as num),
        ),
      ),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await _load(
        'inventoryPurchaseRequests',
        id,
        'Purchase request',
      );
      _requireOwnDraft(existing);
      final history = [
        ...(existing['history'] as List? ?? []),
        if (submit) _historyEntry('submit'),
      ];
      await reference.update({
        ...fields,
        if (submit) 'status': 'pending',
        'history': history,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return {'id': id, 'number': existing['number']};
    }
    final number = await _nextNumber('PR');
    final collection = await schoolCollection('inventoryPurchaseRequests');
    final reference = collection.doc();
    final access = await (await schoolCollection('userAccess')).doc(_uid).get();
    await reference.set({
      ...fields,
      'number': number,
      'campusId': data['campusId'],
      'requestedBy': access.data()?['personErpId'],
      'attachments': <Object?>[],
      'approval': null,
      'status': submit ? 'pending' : 'draft',
      'history': [if (submit) _historyEntry('submit')],
      'requestedDate': dayTimestamp(_today),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': number};
  }

  void _requireOwnDraft(Map<String, dynamic> request) {
    if (request['createdBy'] != _uid) {
      _fail('Only the requester can change this request');
    }
    if (!editablePurchaseRequestStatuses.contains(request['status'])) {
      _fail('Request is ${request['status']}');
    }
  }

  Future<Map<String, dynamic>> _submitPurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await _load(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    _requireOwnDraft(request);
    await reference.update({
      'status': 'pending',
      'history': [...(request['history'] as List), _historyEntry('submit')],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }

  Future<Map<String, dynamic>> _decidePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await _load(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    if (request['status'] != 'pending') {
      _fail('Request is ${request['status']}');
    }
    final decision = data['decision']! as String;
    final comment = _blankToNull(data['comment']);
    if (decision != 'approve' && comment == null) {
      _fail('A comment is required');
    }
    await reference.update({
      'status': switch (decision) {
        'approve' => 'approved',
        'reject' => 'rejected',
        _ => 'revision_requested',
      },
      'history': [
        ...(request['history'] as List),
        _historyEntry(decision, comment),
      ],
      'approval': {
        'performedBy': _uid,
        'performedAt': FieldValue.serverTimestamp(),
        'decision': decision,
        'comment': comment,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }

  Future<Map<String, dynamic>> _cancelPurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await _load(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    if (request['createdBy'] != _uid) {
      _fail('Only the requester can cancel this request');
    }
    if (!cancellablePurchaseRequestStatuses.contains(request['status'])) {
      _fail('Request is ${request['status']}');
    }
    final anyOrdered = (request['lineItems'] as List).any(
      (line) => ((line as Map)['quantityOrdered'] as num) > 0,
    );
    if (anyOrdered) _fail('Part of this request is already ordered');
    await reference.update({
      'status': 'cancelled',
      'history': [
        ...(request['history'] as List),
        _historyEntry('cancel', _blankToNull(data['reason'])),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }

  // --- quotations ----------------------------------------------------------

  Future<Map<String, dynamic>> _loadOrderableRequest(String id) async {
    final (reference: _, data: request) = await _load(
      'inventoryPurchaseRequests',
      id,
      'Purchase request',
    );
    if (!orderablePurchaseRequestStatuses.contains(request['status'])) {
      _fail('Request is ${request['status']}; it must be approved');
    }
    return request;
  }

  ({double subtotal, double total}) _totals(
    List<Map<String, dynamic>> lines, {
    required num discount,
    required num tax,
    required num delivery,
  }) {
    final subtotal = _roundToCents(
      lines.fold<double>(
        0,
        (total, line) =>
            total + (line['quantity']! as num) * (line['unitPrice']! as num),
      ),
    );
    if (discount > subtotal) _fail('Discount exceeds the subtotal');
    return (
      subtotal: subtotal,
      total: _roundToCents(subtotal - discount + tax + delivery),
    );
  }

  Future<Map<String, dynamic>> _saveQuotation(Map<String, Object?> data) async {
    final requestId = data['purchaseRequestId']! as String;
    final request = await _loadOrderableRequest(requestId);
    final vendorId = data['vendorId']! as String;
    final vendor = (await (await _reference(
      'inventoryVendors',
      vendorId,
    )).get()).data();
    if (vendor == null) _fail('Vendor not found');
    if (vendor['status'] != 'active') _fail('Vendor is inactive');
    final lines = _lines(data['lineItems']);
    _requireUniqueLines(lines);
    final requestLines = _lines(request['lineItems']);
    for (final line in lines) {
      final requestLine = requestLines
          .where((candidate) => _lineKey(candidate) == _lineKey(line))
          .firstOrNull;
      if (requestLine == null) {
        _fail('Quotation lines must be lines of the request');
      }
      if ((line['quantity']! as num) > (requestLine['quantity']! as num)) {
        _fail('Quoted quantity exceeds the requested quantity');
      }
    }
    final date = (data['quotationDate'] as String?) ?? _today;
    final validUntil = data['validUntil']! as String;
    if (validUntil.compareTo(date) < 0) {
      _fail('Valid until is before the quotation date');
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
    final totals = _totals(
      storedLines,
      discount: discount,
      tax: tax,
      delivery: delivery,
    );
    final fields = {
      'vendorId': vendorId,
      'vendorRef': _blankToNull(data['vendorRef']),
      'quotationDate': dayTimestamp(date),
      'validUntil': dayTimestamp(validUntil),
      'deliveryDays': data['deliveryDays'],
      'lineItems': storedLines,
      'discount': discount,
      'tax': tax,
      'delivery': delivery,
      'remarks': _blankToNull(data['remarks']),
      'subtotal': totals.subtotal,
      'total': totals.total,
      'status': data['final'] == true ? 'final' : 'draft',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await _load(
        'inventoryQuotations',
        id,
        'Quotation',
      );
      if (existing['status'] != 'draft') {
        _fail('Only draft quotations can be edited');
      }
      await reference.update(fields);
      return {'id': id, 'number': existing['number']};
    }
    final number = await _nextNumber('QT');
    final reference = (await schoolCollection('inventoryQuotations')).doc();
    await reference.set({
      ...fields,
      'number': number,
      'purchaseRequestId': requestId,
      'campusId': request['campusId'],
      'selected': false,
      'selectionReason': null,
      'attachments': <Object?>[],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
    return {'id': reference.id, 'number': number};
  }

  Future<Map<String, dynamic>> _selectQuotation(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: quotation) = await _load(
      'inventoryQuotations',
      data['id']! as String,
      'Quotation',
    );
    await _loadOrderableRequest(quotation['purchaseRequestId'] as String);
    if (quotation['status'] != 'final') {
      _fail('Only final quotations can be selected');
    }
    if (readDay(quotation['validUntil']).compareTo(_today) < 0) {
      _fail('Quotation has expired');
    }
    final siblings = await (await schoolCollection('inventoryQuotations'))
        .where('purchaseRequestId', isEqualTo: quotation['purchaseRequestId'])
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final sibling in siblings.docs) {
      if (sibling.id == reference.id || sibling.data()['selected'] != true) {
        continue;
      }
      final orders = await (await schoolCollection('inventoryPurchaseOrders'))
          .where('quotationId', isEqualTo: sibling.id)
          .get();
      if (orders.docs.any((order) => order.data()['status'] != 'cancelled')) {
        _fail('A purchase order already uses the selected quotation');
      }
      batch.update(sibling.reference, {
        'selected': false,
        'selectionReason': null,
      });
    }
    batch.update(reference, {
      'selected': true,
      'selectionReason': (data['reason']! as String).trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {'id': reference.id, 'number': quotation['number']};
  }

  // --- invoices ------------------------------------------------------------

  double _invoiceTotal(num subtotal, num tax, num discount) {
    if (discount > subtotal) _fail('Discount exceeds the subtotal');
    return _roundToCents(subtotal - discount + tax);
  }

  Future<Map<String, dynamic>> _saveInvoice(Map<String, Object?> data) async {
    final orderId = data['purchaseOrderId']! as String;
    final (reference: _, data: order) = await _load(
      'inventoryPurchaseOrders',
      orderId,
      'Purchase order',
    );
    if (['draft', 'cancelled'].contains(order['status'])) {
      _fail('Order is ${order['status']}');
    }
    final invoiceDate = data['invoiceDate']! as String;
    final dueDate = _blankToNull(data['dueDate']);
    if (invoiceDate.compareTo(_today) > 0) {
      _fail('Invoice date is in the future');
    }
    if (dueDate != null && dueDate.compareTo(invoiceDate) < 0) {
      _fail('Due date is before the invoice date');
    }
    final receiptIds = [...((data['receiptIds'] as List?) ?? [])];
    for (final receiptId in receiptIds) {
      final receipt = (await (await _reference(
        'inventoryReceipts',
        receiptId as String,
      )).get()).data();
      if (receipt?['purchaseOrderId'] != orderId) {
        _fail('Receiving reference does not belong to this order');
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
      'remarks': _blankToNull(data['remarks']),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await _load(
        'inventoryInvoices',
        id,
        'Invoice',
      );
      if (existing['paymentStatus'] != 'unpaid') {
        _fail('Invoice is ${existing['paymentStatus']}');
      }
      await reference.update(fields);
      return {'id': id};
    }
    final invoiceNumber = (data['invoiceNumber']! as String).trim();
    final duplicates = await (await schoolCollection('inventoryInvoices'))
        .where('vendorId', isEqualTo: order['vendorId'])
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .get();
    if (duplicates.docs.any(
      (duplicate) => duplicate.data()['paymentStatus'] != 'cancelled',
    )) {
      _fail('Invoice "$invoiceNumber" already exists for this vendor');
    }
    final reference = (await schoolCollection('inventoryInvoices')).doc();
    await reference.set({
      ...fields,
      'vendorId': order['vendorId'],
      'purchaseOrderId': orderId,
      'purchaseOrderNumber': order['number'],
      'invoiceNumber': invoiceNumber,
      'campusId': order['campusId'],
      'paymentStatus': 'unpaid',
      'paidAmount': 0,
      'payment': null,
      'attachments': <Object?>[],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
    return {'id': reference.id};
  }

  Future<Map<String, dynamic>> _setInvoicePayment(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: invoice) = await _load(
      'inventoryInvoices',
      data['id']! as String,
      'Invoice',
    );
    if (invoice['paymentStatus'] == 'cancelled') _fail('Invoice is cancelled');
    final paidAmount = data['paidAmount']! as num;
    final total = invoice['total'] as num;
    if (paidAmount < 0) _fail('Invalid paid amount');
    if (paidAmount > total) _fail('Paid amount exceeds the invoice total');
    final paymentStatus = paidAmount >= total
        ? 'paid'
        : paidAmount > 0
        ? 'partially_paid'
        : 'unpaid';
    await reference.update({
      'paidAmount': paidAmount,
      'outstanding': _roundToCents(total - paidAmount),
      'paymentStatus': paymentStatus,
      'payment': {
        'reference': _blankToNull(data['reference']),
        'date': dayTimestamp((data['paidDate'] as String?) ?? _today),
        'performedBy': _uid,
      },
      // Every update is kept: `amount` is what this entry added (negative for a correction).
      'payments': FieldValue.arrayUnion([
        {
          'amount': _roundToCents(
            paidAmount - ((invoice['paidAmount'] as num?) ?? 0),
          ),
          'paidAmount': paidAmount,
          'reference': _blankToNull(data['reference']),
          'date': dayTimestamp((data['paidDate'] as String?) ?? _today),
          'performedBy': _uid,
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'paymentStatus': paymentStatus};
  }

  Future<Map<String, dynamic>> _cancelInvoice(Map<String, Object?> data) async {
    final (:reference, data: invoice) = await _load(
      'inventoryInvoices',
      data['id']! as String,
      'Invoice',
    );
    if (invoice['paymentStatus'] != 'unpaid') {
      _fail('Invoice is ${invoice['paymentStatus']}');
    }
    final reason = _blankToNull(data['reason']);
    if (reason == null) _fail('A reason is required');
    await reference.update({
      'paymentStatus': 'cancelled',
      'cancelReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id};
  }
}
