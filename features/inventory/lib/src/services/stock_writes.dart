import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';

/// Client-side stock writes: Receive Stock (`inventory-receipt-confirm`), receiving goods against a purchase order (`inventory-purchaseOrder-receive`), issue request submit and approve/reject, issuing stock (`inventory-issue-create`) confirming an issue's receipt returns against an issue requesting, stock adjustments and unavailable stock.
///
/// One Firestore transaction writes the receipt, its balances, the ledger rows
/// and the GRN counter. Business checks live here and in `firestore.rules`
/// (`inventory.stock.operate`). There is no audit log, no low-stock
/// notification and no retry idempotency.
class StockWrites {
  /// Action names `StockProvider.act` routes here instead of to a callable.
  static const names = {
    'inventory-receipt-confirm',
    'inventory-purchaseOrder-receive',
    'inventory-issueRequest-submit',
    'inventory-issueRequest-decide',
    'inventory-issueRequest-cancel',
    'inventory-issueRequest-close',
    'inventory-issue-create',
    'inventory-issue-acknowledge',
    'inventory-return-create',
    'inventory-adjustment-create',
    'inventory-unavailable-report',
    'inventory-unavailable-resolve',
  };

  static const _adjustmentReasons = [
    'count_correction',
    'data_entry',
    'missing',
    'excess',
    'other',
  ];

  static const _sources = ['opening', 'return'];

  Future<Map<String, dynamic>> run(String name, Map<String, Object?> data) =>
      switch (name) {
        'inventory-receipt-confirm' => _confirmReceipt(data),
        'inventory-purchaseOrder-receive' => _receivePurchaseOrder(data),
        'inventory-issueRequest-submit' => _submitIssueRequest(data),
        'inventory-issueRequest-decide' => _decideIssueRequest(data),
        'inventory-issueRequest-cancel' => _endIssueRequest(data, cancel: true),
        'inventory-issueRequest-close' => _endIssueRequest(data, cancel: false),
        'inventory-issue-create' => _issueStock(data),
        'inventory-issue-acknowledge' => _acknowledgeIssue(data),
        'inventory-return-create' => _createReturn(data),
        'inventory-adjustment-create' => _adjustStock(data),
        'inventory-unavailable-report' => _reportUnavailable(data),
        'inventory-unavailable-resolve' => _resolveUnavailable(data),
        _ => throw ArgumentError.value(name, 'name'),
      };

  Never _fail(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );

  String? _blankToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// `collection/id[/sub/id]` under the school.
  Future<DocumentReference<Map<String, dynamic>>> _doc(String path) async {
    final segments = path.split('/');
    return (await branchCollection(segments.first))
        .doc(segments.skip(1).join('/'));
  }

  /// Active, stock-tracked item whose variant requirement matches [variantId].
  Future<Map<String, dynamic>> _stockItem(
    Transaction transaction,
    String itemId,
    String? variantId, {
    bool inactiveOk = false,
  }) async {
    final item = (await transaction.get(await _doc('inventoryItems/$itemId')))
        .data();
    if (item == null) _fail('Item not found');
    final name = item['name'];
    if (!inactiveOk && item['status'] != 'active') _fail('$name is inactive');
    if (item['tracking'] == 'asset') {
      _fail('$name is an individual asset; assets are managed separately');
    }
    final hasVariants =
        ((item['variantAttrs'] as List?) ?? const []).isNotEmpty;
    if (hasVariants != (variantId != null)) {
      _fail(hasVariants ? '$name needs a variant' : '$name has no variants');
    }
    if (variantId != null) {
      final variant = (await transaction.get(
        await _doc('inventoryItems/$itemId/variants/$variantId'),
      )).data();
      if (variant == null) _fail('Variant not found');
      if (!inactiveOk && variant['status'] != 'active') {
        _fail('Variant is inactive');
      }
    }
    return item;
  }

  String get _financialYear => DateTime.now().toIndianTime().financialYear;

  Future<Map<String, dynamic>> _decideIssueRequest(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = data['id']! as String;
    final approve = data['decision'] == 'approve';
    final comment = _blankToNull(data['comment']);
    if (!approve && comment == null) _fail('A reason is required to reject');
    final overrides = {
      for (final line in (data['lineItems'] as List? ?? const []))
        (line as Map)['index'] as int: (line['quantityApproved'] as num)
            .toDouble(),
    };

    final reference = await _doc('inventoryIssueRequests/$id');
    final current = (await reference.get()).data();
    if (current == null) _fail('Issue request not found');
    final approvedLines = <Map<String, dynamic>>[];
    if (approve) {
      final lines = (current['lineItems'] as List).cast<Map<String, dynamic>>();
      for (final (index, line) in lines.indexed) {
        final requested = (line['quantityRequested'] as num).toDouble();
        final approved = overrides[index] ?? requested;
        if (approved > requested) {
          _fail('Approved quantity exceeds the request');
        }
        if (approved > 0 &&
            approved >
                await _available(
                  current['storeId'] as String,
                  line['itemId'] as String,
                  line['variantId'] as String?,
                )) {
          _fail('Approved quantity exceeds available stock');
        }
        approvedLines.add({...line, 'quantityApproved': approved});
      }
      if (!approvedLines.any((line) => (line['quantityApproved'] as num) > 0)) {
        _fail('Nothing approved; reject the request instead');
      }
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final status = (await transaction.get(reference)).data()?['status'];
      if (status != 'pending') _fail('Request is already $status');
      transaction.update(reference, {
        'status': approve ? 'approved' : 'rejected',
        'lineItems': ?(approve ? approvedLines : null),
        'approval': {
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
          'comment': comment,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// The requester withdraws a pending request (`cancel`), or a stock operator closes what is
  /// still outstanding on an approved / partly issued one (`close`). Either needs a reason.
  Future<Map<String, dynamic>> _endIssueRequest(
    Map<String, Object?> data, {
    required bool cancel,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = data['id']! as String;
    final reason = _blankToNull(data['reason']);
    if (reason == null) _fail('A reason is required');
    final reference = await _doc('inventoryIssueRequests/$id');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final request = (await transaction.get(reference)).data();
      if (request == null) _fail('Issue request not found');
      final status = request['status'];
      if (cancel
          ? status != 'pending' || request['createdBy'] != uid
          : status != 'approved' && status != 'partially_issued') {
        _fail('Request is $status');
      }
      transaction.update(reference, {
        'status': cancel ? 'cancelled' : 'closed',
        'closure': {
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
          'reason': reason,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// Issuable (non-expired) stock of an item in a store. Issuance re-checks it, so an
  /// approver who may not read balances (`inventory.stock.view`) is not blocked here.
  Future<double> _available(
    String storeId,
    String itemId,
    String? variantId,
  ) async {
    final today = todayIST();
    try {
      final snapshot = await (await branchCollection('inventoryBalances'))
          .where('storeId', isEqualTo: storeId)
          .where('itemId', isEqualTo: itemId)
          .get();
      return snapshot.docs
          .map((document) => document.data())
          .where(
            (balance) =>
                balance['variantId'] == variantId &&
                (readDayOrNull(balance['expiryDate'])?.compareTo(today) ?? 1) >=
                    0,
          )
          .fold<double>(
            0,
            (total, balance) =>
                total + (balance['quantityAvailable'] as num).toDouble(),
          );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return double.infinity;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _submitIssueRequest(
    Map<String, Object?> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final claims = (await user.getIdTokenResult()).claims;
    final financialYear = _financialYear;
    final storeId = data['storeId']! as String;
    final purpose = _blankToNull(data['purpose']);
    if (purpose == null || purpose.length > 500) {
      _fail('Purpose is required (500 characters at most)');
    }
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) _fail('Add at least one item');
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      _fail('Each item (and variant) may appear once');
    }
    if (lines.any((line) => ((line['quantity'] as num?) ?? 0) <= 0)) {
      _fail('Each line needs a quantity');
    }

    final storeRef = await _doc('inventoryStores/$storeId');
    final counterRef = await _doc('counters/ISR_$financialYear');
    final requestRef = (await branchCollection('inventoryIssueRequests')).doc();
    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;
      for (final line in lines) {
        await _stockItem(
          transaction,
          line['itemId']! as String,
          line['variantId'] as String?,
        );
      }
      final requestNumber =
          'ISR/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(requestRef, {
        'number': requestNumber,
        'storeId': storeId,
        'destination': _blankToNull(data['destination']),
        'purpose': purpose,
        'remarks': _blankToNull(data['remarks']),
        'requesterId': claims?['personErpId'],
        'lineItems': [
          for (final line in lines)
            {
              'itemId': line['itemId'],
              'variantId': line['variantId'],
              'quantityRequested': line['quantity'],
              'quantityApproved': null,
              'quantityIssued': 0,
            },
        ],
        'itemIds': [for (final line in lines) line['itemId']],
        'status': 'pending',
        'approval': null,
        'transactionDate': dayTimestamp(todayIST()),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return requestNumber;
    });
    return {'id': requestRef.id, 'number': number};
  }

  Future<Map<String, dynamic>> _confirmReceipt(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now().toIndianTime();
    final today = now.toApiDate();
    final financialYear = _financialYear;

    final storeId = data['storeId']! as String;
    final source = data['source']! as String;
    if (!_sources.contains(source)) _fail('Invalid receipt source');
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) _fail('Add at least one item');
    // Batches of one item are separate balances, so the batch is part of the key.
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}__'
            '${_blankToNull(line['batchNumber']) ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      _fail('Each item, variant and batch may appear once');
    }

    final storeRef = await _doc('inventoryStores/$storeId');
    final counterRef = await _doc('counters/GRN_$financialYear');
    final receiptRef = (await branchCollection('inventoryReceipts')).doc();
    final movements = await branchCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');

      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;

      final prepared = <_ReceiptLine>[];
      for (final line in lines) {
        final itemId = line['itemId']! as String;
        final variantId = line['variantId'] as String?;
        final item = await _stockItem(transaction, itemId, variantId);
        final name = item['name'];

        final accepted = (line['quantityAccepted'] as num? ?? 0).toDouble();
        final rejected = (line['quantityRejected'] as num? ?? 0).toDouble();
        if (accepted < 0 || rejected < 0 || accepted + rejected <= 0) {
          _fail('Each line needs a quantity');
        }

        String? batchNumber;
        String? expiryDate;
        if (item['tracking'] == 'batch') {
          batchNumber = _blankToNull(line['batchNumber']);
          if (batchNumber == null) _fail('$name needs a batch number');
          expiryDate = _blankToNull(line['expiryDate']);
          if (expiryDate != null && expiryDate.compareTo(today) < 0) {
            _fail('Expired batches cannot be received');
          }
        }

        final balanceId = [
          storeId,
          itemId,
          variantId ?? '-',
          batchNumber == null ? '-' : Uri.encodeComponent(batchNumber),
        ].join('__');
        final balanceRef = await _doc('inventoryBalances/$balanceId');
        prepared.add(
          _ReceiptLine(
            itemId: itemId,
            variantId: variantId,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            accepted: accepted,
            rejected: rejected,
            unitCost:
                (line['unitCost'] as num?)?.toDouble() ??
                (item['defaultPrice'] as num?)?.toDouble() ??
                0,
            condition: _blankToNull(line['condition']),
            reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
            balanceId: balanceId,
            balanceRef: balanceRef,
            balance: accepted > 0
                ? (await transaction.get(balanceRef)).data()
                : null,
          ),
        );
      }

      // Then writes.
      final grnNumber = 'GRN/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      var sequence = 0;
      for (final line in prepared) {
        if (line.accepted <= 0) continue;
        _addStock(
          transaction,
          movements,
          reference: line.balanceRef,
          balance: line.balance,
          storeId: storeId,
          itemId: line.itemId,
          variantId: line.variantId,
          batchNumber: line.batchNumber,
          expiryDate: line.expiryDate,
          quantity: line.accepted,
          unitCost: line.unitCost,
          reorderLevel: line.reorderLevel,
          type: 'receive',
          referenceType: 'receipt',
          referenceId: receiptRef.id,
          sequence: sequence++,
          ledger: {
            'transactionDate': dayTimestamp(today),
            'financialYear': financialYear,
            'createdBy': uid,
          },
        );
      }
      transaction.set(receiptRef, {
        'number': grnNumber,
        'storeId': storeId,
        'source': source,
        'reference': _blankToNull(data['reference']),
        'remarks': _blankToNull(data['remarks']),
        'lineItems': [
          for (final line in prepared)
            {
              'itemId': line.itemId,
              'variantId': line.variantId,
              'batchNumber': line.batchNumber,
              'manufacturingDate': null,
              'expiryDate': dayTimestampOrNull(line.expiryDate),
              'unitCost': line.unitCost,
              'condition': line.condition,
              'quantityReceived': line.accepted + line.rejected,
              'quantityAccepted': line.accepted,
              'quantityRejected': line.rejected,
            },
        ],
        'itemIds': {for (final line in prepared) line.itemId}.toList(),
        'attachments': <Object?>[],
        'status': 'confirmed',
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return grnNumber;
    });
    return {'id': receiptRef.id, 'number': number};
  }

  /// One delivery against a PO. Accepted quantity enters the store at the PO unit price;
  /// rejected quantity is recorded but never becomes stock; asset units are counted on the
  /// order but never enter stock either (each is registered individually). Unit cost
  /// excludes PO discount, tax and delivery.
  Future<Map<String, dynamic>> _receivePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now().toIndianTime().toApiDate();
    final financialYear = _financialYear;
    final storeId = data['storeId']! as String;
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) _fail('Add at least one item');
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      _fail('Each item (and variant) may appear once');
    }

    final orderRef = await _doc(
      'inventoryPurchaseOrders/${data['purchaseOrderId']}',
    );
    final storeRef = await _doc('inventoryStores/$storeId');
    final counterRef = await _doc('counters/GRN_$financialYear');
    final receiptRef = (await branchCollection('inventoryReceipts')).doc();
    final movements = await branchCollection('inventoryMovements');
    // A query cannot run inside a transaction, so the request's other live orders are read first.
    final order = (await orderRef.get()).data();
    if (order == null) _fail('Purchase order not found');
    final requestId = (order['purchaseRequestIds'] as List).first as String;
    final requestRef = await _doc('inventoryPurchaseRequests/$requestId');
    const live = ['issued', 'acknowledged', 'partially_received'];
    final otherLiveOrders =
        (await (await branchCollection('inventoryPurchaseOrders'))
                .where('purchaseRequestIds', arrayContains: requestId)
                .get())
            .docs
            .any(
              (other) =>
                  other.id != orderRef.id &&
                  live.contains(other.data()['status']),
            );

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final purchaseOrder = (await transaction.get(orderRef)).data()!;
      if (!live.contains(purchaseOrder['status'])) {
        _fail('Order is ${purchaseOrder['status']}');
      }
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;
      final orderLines = [
        for (final line in (purchaseOrder['lineItems'] as List))
          Map<String, dynamic>.from(line as Map),
      ];
      final prepared = <({_ReceiptLine line, Map<String, dynamic> row})>[];
      for (final line in lines) {
        final itemId = line['itemId']! as String;
        final variantId = line['variantId'] as String?;
        final orderLine = orderLines
            .where(
              (candidate) =>
                  candidate['itemId'] == itemId &&
                  candidate['variantId'] == variantId,
            )
            .firstOrNull;
        if (orderLine == null) {
          _fail('Receiving lines must be lines of the order');
        }
        final accepted = (line['quantityAccepted'] as num? ?? 0).toDouble();
        final rejected = (line['quantityRejected'] as num? ?? 0).toDouble();
        if (accepted < 0 || rejected < 0 || accepted + rejected <= 0) {
          _fail('Each line needs a quantity');
        }
        final got = accepted + rejected;
        // Only accepted units fill the order; rejected ones leave it open for a replacement.
        if (got >
            (orderLine['quantityOrdered']! as num) -
                (orderLine['quantityAccepted']! as num)) {
          _fail('Received quantity exceeds what is still due on the order');
        }
        final rawItem = (await transaction.get(
          await _doc('inventoryItems/$itemId'),
        )).data();
        if (rawItem == null) _fail('Item not found');
        final asset = rawItem['tracking'] == 'asset';
        if (asset && got != got.roundToDouble()) {
          _fail('Assets are received in whole units');
        }
        String? batchNumber;
        String? expiryDate;
        Map<String, dynamic>? balance;
        var balanceRef = counterRef;
        if (!asset) {
          final item = await _stockItem(transaction, itemId, variantId);
          if (item['tracking'] == 'batch') {
            batchNumber = _blankToNull(line['batchNumber']);
            if (batchNumber == null) {
              _fail('${item['name']} needs a batch number');
            }
            expiryDate = _blankToNull(line['expiryDate']);
            if (expiryDate != null && expiryDate.compareTo(today) < 0) {
              _fail('Expired batches cannot be received');
            }
          }
          final balanceId = [
            storeId,
            itemId,
            variantId ?? '-',
            batchNumber == null ? '-' : Uri.encodeComponent(batchNumber),
          ].join('__');
          balanceRef = await _doc('inventoryBalances/$balanceId');
          if (accepted > 0) {
            balance = (await transaction.get(balanceRef)).data();
          }
        }
        final unitCost = (orderLine['unitPrice']! as num).toDouble();
        prepared.add((
          line: _ReceiptLine(
            itemId: itemId,
            variantId: variantId,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            accepted: accepted,
            rejected: rejected,
            unitCost: unitCost,
            condition: _blankToNull(line['condition']),
            reorderLevel: (rawItem['reorderLevel'] as num?)?.toDouble(),
            balanceId: balanceRef.id,
            balanceRef: balanceRef,
            balance: balance,
          ),
          row: {'asset': asset, 'orderLine': orderLine},
        ));
      }
      final requestSnapshot = await transaction.get(requestRef);

      // Then writes.
      final grnNumber = 'GRN/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      var sequence = 0;
      final rows = <Map<String, Object?>>[];
      for (final (:line, :row) in prepared) {
        final orderLine = row['orderLine'] as Map<String, dynamic>;
        if (line.accepted > 0 && row['asset'] != true) {
          _addStock(
            transaction,
            movements,
            reference: line.balanceRef,
            balance: line.balance,
            storeId: storeId,
            itemId: line.itemId,
            variantId: line.variantId,
            batchNumber: line.batchNumber,
            expiryDate: line.expiryDate,
            quantity: line.accepted,
            unitCost: line.unitCost,
            reorderLevel: line.reorderLevel,
            type: 'receive',
            referenceType: 'receipt',
            referenceId: receiptRef.id,
            sequence: sequence++,
            ledger: {
              'transactionDate': dayTimestamp(today),
              'financialYear': financialYear,
              'createdBy': uid,
            },
          );
        }
        orderLine['quantityReceived'] =
            (orderLine['quantityReceived']! as num) +
            line.accepted +
            line.rejected;
        orderLine['quantityAccepted'] =
            (orderLine['quantityAccepted']! as num) + line.accepted;
        orderLine['quantityRejected'] =
            (orderLine['quantityRejected']! as num) + line.rejected;
        rows.add({
          'itemId': line.itemId,
          'variantId': line.variantId,
          'batchNumber': line.batchNumber,
          'manufacturingDate': null,
          'expiryDate': dayTimestampOrNull(line.expiryDate),
          'unitCost': line.unitCost,
          'condition': line.condition,
          'remarks': null,
          'quantityReceived': line.accepted + line.rejected,
          'quantityAccepted': line.accepted,
          'quantityRejected': line.rejected,
          'result': line.rejected == 0
              ? 'accepted'
              : line.accepted == 0
              ? 'rejected'
              : 'partial',
        });
      }
      final accepted = prepared.fold<double>(
        0,
        (total, entry) => total + entry.line.accepted,
      );
      final result = rows.every((row) => row['result'] == 'accepted')
          ? 'accepted'
          : accepted == 0
          ? 'rejected'
          : 'partial';
      final full = orderLines.every(
        (line) =>
            (line['quantityAccepted']! as num) >=
            (line['quantityOrdered']! as num),
      );
      transaction.set(receiptRef, {
        'number': grnNumber,
        'storeId': storeId,
        'source': 'purchase_order',
        'purchaseOrderId': orderRef.id,
        'purchaseOrderNumber': purchaseOrder['number'],
        'vendorId': purchaseOrder['vendorId'],
        'reference': _blankToNull(data['deliveryRef']),
        'remarks': _blankToNull(data['remarks']),
        'lineItems': rows,
        'itemIds': {for (final row in rows) row['itemId']}.toList(),
        'attachments': <Object?>[],
        'inspection': {
          'result': result,
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
        },
        'status': 'confirmed',
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(orderRef, {
        'lineItems': orderLines,
        'status': full ? 'fully_received' : 'partially_received',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // The request is completed once its last live order is fully received.
      if (full &&
          !otherLiveOrders &&
          requestSnapshot.data()?['status'] == 'ordered') {
        transaction.update(requestRef, {
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return {
        'id': receiptRef.id,
        'number': grnNumber,
        'purchaseOrderStatus': full ? 'fully_received' : 'partially_received',
      };
    });
  }

  /// The recipient's receipt of an issue is confirmed once.
  Future<Map<String, dynamic>> _acknowledgeIssue(
    Map<String, Object?> data,
  ) async {
    final id = data['id']! as String;
    final reference = await _doc('inventoryIssues/$id');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final issue = (await transaction.get(reference)).data();
      if (issue == null) _fail('Issue not found');
      if (issue['acknowledgement'] != null) _fail('Already acknowledged');
      transaction.update(reference, {
        'acknowledgement': {
          'performedBy': FirebaseAuth.instance.currentUser!.uid,
          'performedAt': FieldValue.serverTimestamp(),
          'remarks': _blankToNull(data['remarks']),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// Takes back issued stock: usable units return to the balance they came from,
  /// damaged ones go to the damaged bucket and the unavailable-stock register.
  Future<Map<String, dynamic>> _createReturn(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = _financialYear;
    final issueId = data['issueId']! as String;
    final returnedBy = Map<String, dynamic>.from(data['returnedBy']! as Map);
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) _fail('Add at least one item');
    if ({for (final line in lines) line['balanceId']}.length != lines.length) {
      _fail('Each line may appear once');
    }

    final issueRef = await _doc('inventoryIssues/$issueId');
    final counterRef = await _doc('counters/RET_$financialYear');
    final returnRef = (await branchCollection('inventoryReturns')).doc();
    final movements = await branchCollection('inventoryMovements');
    final unavailable = await branchCollection('inventoryUnavailableStock');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final issue = (await transaction.get(issueRef)).data();
      if (issue == null) _fail('Issue not found');
      final storeId = issue['storeId']! as String;
      final store = (await transaction.get(
        await _doc('inventoryStores/$storeId'),
      )).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;
      final issueLines = [
        for (final line in (issue['lineItems'] as List))
          Map<String, dynamic>.from(line as Map),
      ];

      final plans = <_ReturnPlan>[];
      for (final line in lines) {
        final usable = (line['quantityUsable'] as num? ?? 0).toDouble();
        final damaged = (line['quantityDamaged'] as num? ?? 0).toDouble();
        final quantity = usable + damaged;
        final issueLine = issueLines.firstWhere(
          (candidate) => candidate['balanceId'] == line['balanceId'],
          orElse: () => _fail('Line is not on the issue'),
        );
        if (usable < 0 || damaged < 0 || quantity <= 0) {
          _fail('Each line needs a quantity');
        }
        final outstanding =
            (issueLine['quantity'] as num) -
            (issueLine['quantityReturned'] as num);
        if (quantity > outstanding) {
          _fail('Only $outstanding outstanding for this line');
        }
        final item = await _stockItem(
          transaction,
          issueLine['itemId']! as String,
          issueLine['variantId'] as String?,
          inactiveOk: true,
        );
        final reference = await _doc('inventoryBalances/${line['balanceId']}');
        final balance = (await transaction.get(reference)).data();
        if (balance == null) _fail('No stock of ${item['name']} in this store');
        plans.add(
          _ReturnPlan(
            issueLine: issueLine,
            reference: reference,
            balance: balance,
            usable: usable,
            damaged: damaged,
            reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
          ),
        );
      }

      // Then writes.
      final returnNumber =
          'RET/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      var sequence = 0;
      for (final plan in plans) {
        final balance = plan.balance;
        final available = (balance['quantityAvailable'] as num) + plan.usable;
        final unitCost = (balance['unitCost'] as num).toDouble();
        transaction.update(plan.reference, {
          'quantityAvailable': available,
          'quantityDamaged': (balance['quantityDamaged'] as num) + plan.damaged,
          'totalQuantityIssued':
              (balance['totalQuantityIssued'] as num) -
              plan.usable -
              plan.damaged,
          'value': (available * unitCost * 100).round() / 100,
          'isBelowReorderLevel':
              plan.reorderLevel != null && available <= plan.reorderLevel!,
          'earliestExpiryDate': available > 0 ? balance['expiryDate'] : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        for (final (bucket, quantity) in [
          ('available', plan.usable),
          ('damaged', plan.damaged),
        ]) {
          if (quantity <= 0) continue;
          transaction.set(movements.doc(), {
            'type': 'return',
            'balanceId': plan.reference.id,
            'itemId': balance['itemId'],
            'variantId': balance['variantId'],
            'storeId': storeId,
            'batchNumber': balance['batchNumber'],
            'quantity': quantity,
            'bucket': bucket,
            'referenceType': 'return',
            'referenceId': returnRef.id,
            'unitCost': unitCost,
            'transactionDate': dayTimestamp(today),
            'financialYear': financialYear,
            'seq': sequence++,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': uid,
          });
        }
        if (plan.damaged > 0) {
          transaction.set(unavailable.doc(), {
            'balanceId': plan.reference.id,
            'itemId': balance['itemId'],
            'variantId': balance['variantId'],
            'storeId': storeId,
            'batchNumber': balance['batchNumber'],
            'quantity': plan.damaged,
            'bucket': 'damaged',
            'reason': 'damaged_return',
            'remarks': null,
            'evidence': null,
            'referenceType': 'return',
            'referenceId': returnRef.id,
            'status': 'open',
            'resolution': null,
            'resolvedAt': null,
            'reportedBy': uid,
            'transactionDate': dayTimestamp(today),
            'financialYear': financialYear,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        plan.issueLine['quantityReturned'] =
            (plan.issueLine['quantityReturned'] as num) +
            plan.usable +
            plan.damaged;
      }
      transaction.set(returnRef, {
        'number': returnNumber,
        'issueId': issueId,
        'storeId': storeId,
        'returnedBy': returnedBy,
        'remarks': _blankToNull(data['remarks']),
        'lineItems': [
          for (final plan in plans)
            {
              'balanceId': plan.reference.id,
              'itemId': plan.issueLine['itemId'],
              'variantId': plan.issueLine['variantId'],
              'quantityUsable': plan.usable,
              'quantityDamaged': plan.damaged,
            },
        ],
        'inspection': {
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
        },
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(issueRef, {
        'lineItems': issueLines,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return returnNumber;
    });
    return {'id': returnRef.id, 'number': number};
  }

  /// Queries cannot run inside a transaction: find each line's balances first,
  /// then re-read them in the transaction so the quantities are current.
  Future<Map<String, List<DocumentReference<Map<String, dynamic>>>>>
  _candidateBalances(String storeId, List<Map<String, dynamic>> lines) async {
    final balances = await branchCollection('inventoryBalances');
    return {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}': [
          for (final document
              in (await balances
                      .where('storeId', isEqualTo: storeId)
                      .where('itemId', isEqualTo: line['itemId'])
                      .get())
                  .docs)
            if (document.data()['variantId'] == line['variantId'])
              document.reference,
        ],
    };
  }

  /// First-expiry-first-out picks covering [quantity]; expired batches never qualify.
  Future<List<_IssuePick>> _allocateStock(
    Transaction transaction,
    List<DocumentReference<Map<String, dynamic>>> references,
    double quantity,
    Object? itemName,
  ) async {
    final today = todayIST();
    final available = <_IssueBalance>[];
    for (final reference in references) {
      final balance = (await transaction.get(reference)).data();
      final expiry = readDayOrNull(balance?['expiryDate']);
      if (balance != null &&
          (balance['quantityAvailable'] as num) > 0 &&
          (expiry == null || expiry.compareTo(today) >= 0)) {
        available.add(_IssueBalance(reference, balance, expiry));
      }
    }
    // First expiry first; stock without an expiry last.
    available.sort(
      (left, right) =>
          (left.expiry ?? '9999-12-31').compareTo(right.expiry ?? '9999-12-31'),
    );
    var left = quantity;
    final picks = <_IssuePick>[];
    for (final balance in available) {
      if (left <= 0) break;
      final take = left < balance.quantityAvailable
          ? left
          : balance.quantityAvailable;
      picks.add(_IssuePick(balance, take));
      left -= take;
    }
    if (left > 0) _fail('Insufficient stock of $itemName');
    return picks;
  }

  /// Takes a pick out of its balance and appends the ledger row ([ledger] holds the shared fields).
  /// A negative pick puts stock back (adjustments).
  void _takeStock(
    Transaction transaction,
    CollectionReference<Map<String, dynamic>> movements,
    _IssuePick pick, {
    required String type,
    required String referenceType,
    required String referenceId,
    required double? reorderLevel,
    required int sequence,
    required Map<String, Object?> ledger,
  }) {
    final balance = pick.balance;
    final available = balance.quantityAvailable - pick.quantity;
    final unitCost = (balance.data['unitCost'] as num).toDouble();
    transaction.update(balance.reference, {
      'quantityAvailable': available,
      if (type == 'issue')
        'totalQuantityIssued':
            (balance.data['totalQuantityIssued'] as num) + pick.quantity,
      'value': (available * unitCost * 100).round() / 100,
      'isBelowReorderLevel': reorderLevel != null && available <= reorderLevel,
      'earliestExpiryDate': available > 0 ? balance.data['expiryDate'] : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(movements.doc(), {
      'type': type,
      'balanceId': balance.reference.id,
      'itemId': balance.data['itemId'],
      'variantId': balance.data['variantId'],
      'batchNumber': balance.data['batchNumber'],
      'quantity': -pick.quantity,
      'bucket': 'available',
      'referenceType': referenceType,
      'referenceId': referenceId,
      'unitCost': unitCost,
      'seq': sequence,
      'createdAt': FieldValue.serverTimestamp(),
      ...ledger,
    });
  }

  /// Adds [quantity] to a balance (created when missing) at weighted-average cost
  /// and appends the ledger row ([ledger] holds the shared fields).
  void _addStock(
    Transaction transaction,
    CollectionReference<Map<String, dynamic>> movements, {
    required DocumentReference<Map<String, dynamic>> reference,
    required Map<String, dynamic>? balance,
    required String storeId,
    required String itemId,
    required String? variantId,
    required String? batchNumber,
    required String? expiryDate,
    required double quantity,
    required double unitCost,
    required double? reorderLevel,
    required String type,
    required String referenceType,
    required String referenceId,
    required int sequence,
    required Map<String, Object?> ledger,
    Object? manufacturingDate,
  }) {
    final have = (balance?['quantityAvailable'] as num? ?? 0).toDouble();
    final cost = (balance?['unitCost'] as num? ?? 0).toDouble();
    final available = have + quantity;
    final averageCost = (have * cost + quantity * unitCost) / available;
    final storedExpiry = readDayOrNull(balance?['expiryDate']);
    if (storedExpiry != null &&
        expiryDate != null &&
        storedExpiry != expiryDate) {
      _fail('Batch $batchNumber already exists with expiry $storedExpiry');
    }
    final expiry = storedExpiry ?? expiryDate;
    transaction.set(reference, {
      'storeId': storeId,
      'itemId': itemId,
      'variantId': variantId,
      'batchNumber': batchNumber,
      'manufacturingDate': balance?['manufacturingDate'] ?? manufacturingDate,
      'expiryDate': dayTimestampOrNull(expiry),
      'quantityAvailable': available,
      'quantityReserved': balance?['quantityReserved'] ?? 0,
      'quantityDamaged': balance?['quantityDamaged'] ?? 0,
      'quantityExpired': balance?['quantityExpired'] ?? 0,
      'totalQuantityReceived':
          (balance?['totalQuantityReceived'] as num? ?? 0) + quantity,
      'totalQuantityIssued': balance?['totalQuantityIssued'] ?? 0,
      'unitCost': averageCost,
      'value': (available * averageCost * 100).round() / 100,
      'isBelowReorderLevel': reorderLevel != null && available <= reorderLevel,
      'earliestExpiryDate': dayTimestampOrNull(expiry),
      'createdAt': balance?['createdAt'] ?? FieldValue.serverTimestamp(),
      'createdBy':
          balance?['createdBy'] ?? FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(movements.doc(), {
      'type': type,
      'balanceId': reference.id,
      'itemId': itemId,
      'variantId': variantId,
      'storeId': storeId,
      'batchNumber': batchNumber,
      'quantity': quantity,
      'bucket': 'available',
      'referenceType': referenceType,
      'referenceId': referenceId,
      'unitCost': unitCost,
      'seq': sequence,
      'createdAt': FieldValue.serverTimestamp(),
      ...ledger,
    });
  }

  /// A manual correction of one balance's available quantity, with a reason.
  Future<Map<String, dynamic>> _adjustStock(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = _financialYear;
    final storeId = data['storeId']! as String;
    final itemId = data['itemId']! as String;
    final variantId = data['variantId'] as String?;
    final batchNumber = _blankToNull(data['batchNumber']);
    final delta = (data['delta']! as num).toDouble();
    final reason = data['reason']! as String;
    final remarks = _blankToNull(data['remarks']);
    if (delta == 0 || delta.abs() > 1000000) {
      _fail('Quantity change must not be 0');
    }
    if (!_adjustmentReasons.contains(reason)) _fail('Invalid reason');
    if (reason == 'other' && remarks == null) _fail('Describe the reason');
    if (remarks != null && remarks.length > 500) _fail('Note is too long');
    if ((reason == 'missing' && delta > 0) ||
        (reason == 'excess' && delta < 0)) {
      _fail('Reason does not match the direction');
    }

    final storeRef = await _doc('inventoryStores/$storeId');
    final balanceRef = await _doc(
      'inventoryBalances/${[storeId, itemId, variantId ?? '-', batchNumber == null ? '-' : Uri.encodeComponent(batchNumber)].join('__')}',
    );
    final counterRef = await _doc('counters/ADJ_$financialYear');
    final adjustmentRef = (await branchCollection('inventoryAdjustments'))
        .doc();
    final movements = await branchCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final item = await _stockItem(transaction, itemId, variantId);
      final balance = (await transaction.get(balanceRef)).data();
      if (balance == null) _fail('No stock of ${item['name']} in this store');
      final before = (balance['quantityAvailable'] as num).toDouble();
      if (before + delta < 0) {
        _fail('Insufficient stock ($before available)');
      }
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;

      // Then writes.
      final adjustmentNumber =
          'ADJ/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // A negative pick puts stock back, so one helper moves the balance both ways.
      _takeStock(
        transaction,
        movements,
        _IssuePick(
          _IssueBalance(
            balanceRef,
            balance,
            readDayOrNull(balance['expiryDate']),
          ),
          -delta,
        ),
        type: 'adjust',
        referenceType: 'adjustment',
        referenceId: adjustmentRef.id,
        reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
        sequence: 0,
        ledger: {
          'storeId': storeId,
          'transactionDate': dayTimestamp(today),
          'financialYear': financialYear,
          'createdBy': uid,
        },
      );
      transaction.set(adjustmentRef, {
        'number': adjustmentNumber,
        'balanceId': balanceRef.id,
        'itemId': itemId,
        'variantId': variantId,
        'storeId': storeId,
        'batchNumber': batchNumber,
        'before': before,
        'delta': delta,
        'after': before + delta,
        'reason': reason,
        'remarks': remarks,
        'evidence': null,
        'approval': null,
        'status': 'completed',
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return adjustmentNumber;
    });
    return {'id': adjustmentRef.id, 'number': number};
  }

  static const _bucketFields = {
    'damaged': 'quantityDamaged',
    'expired': 'quantityExpired',
  };

  /// A ledger row for one bucket of a balance.
  void _writeMovement(
    Transaction transaction,
    CollectionReference<Map<String, dynamic>> movements,
    DocumentReference<Map<String, dynamic>> balanceRef,
    Map<String, dynamic> balance, {
    required String type,
    required String bucket,
    required double quantity,
    required String referenceId,
    required int sequence,
    required Map<String, Object?> ledger,
  }) {
    transaction.set(movements.doc(), {
      'type': type,
      'balanceId': balanceRef.id,
      'itemId': balance['itemId'],
      'variantId': balance['variantId'],
      'batchNumber': balance['batchNumber'],
      'quantity': quantity,
      'bucket': bucket,
      'referenceType': 'unavailable',
      'referenceId': referenceId,
      'unitCost': balance['unitCost'],
      'seq': sequence,
      'createdAt': FieldValue.serverTimestamp(),
      ...ledger,
    });
  }

  /// Moves usable stock out of `quantityAvailable` into the unavailable-stock register.
  Future<Map<String, dynamic>> _reportUnavailable(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = _financialYear;
    final storeId = data['storeId']! as String;
    final itemId = data['itemId']! as String;
    final variantId = data['variantId'] as String?;
    final batchNumber = _blankToNull(data['batchNumber']);
    final quantity = (data['quantity']! as num).toDouble();
    final reason = data['reason']! as String;
    final remarks = _blankToNull(data['remarks']);
    if (quantity <= 0) _fail('Enter a quantity');
    if (!const ['damaged', 'expired', 'lost'].contains(reason)) {
      _fail('Invalid reason');
    }
    if (remarks == null || remarks.length > 500) {
      _fail('Details are required (500 characters at most)');
    }
    final bucket = reason == 'lost' ? null : reason;

    final storeRef = await _doc('inventoryStores/$storeId');
    final balanceRef = await _doc(
      'inventoryBalances/${[storeId, itemId, variantId ?? '-', batchNumber == null ? '-' : Uri.encodeComponent(batchNumber)].join('__')}',
    );
    final entryRef = (await branchCollection('inventoryUnavailableStock'))
        .doc();
    final movements = await branchCollection('inventoryMovements');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final item = await _stockItem(
        transaction,
        itemId,
        variantId,
        inactiveOk: true,
      );
      final balance = (await transaction.get(balanceRef)).data();
      if (balance == null) _fail('No stock of ${item['name']} in this store');
      final expiry = readDayOrNull(balance['expiryDate']);
      if (reason == 'expired' &&
          (expiry == null || expiry.compareTo(today) >= 0)) {
        _fail('Batch has not expired');
      }
      final available = (balance['quantityAvailable'] as num) - quantity;
      if (available < 0) {
        _fail('Insufficient stock (${balance['quantityAvailable']} available)');
      }

      // Then writes.
      final type = switch (reason) {
        'damaged' => 'damage',
        'expired' => 'expire',
        _ => 'writeoff',
      };
      final ledger = <String, Object?>{
        'storeId': storeId,
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdBy': uid,
      };
      final unitCost = (balance['unitCost'] as num).toDouble();
      final reorderLevel = (item['reorderLevel'] as num?)?.toDouble();
      transaction.update(balanceRef, {
        'quantityAvailable': available,
        if (bucket != null)
          _bucketFields[bucket]!:
              (balance[_bucketFields[bucket]] as num) + quantity,
        'value': (available * unitCost * 100).round() / 100,
        'isBelowReorderLevel':
            reorderLevel != null && available <= reorderLevel,
        'earliestExpiryDate': available > 0 ? balance['expiryDate'] : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeMovement(
        transaction,
        movements,
        balanceRef,
        balance,
        type: type,
        bucket: 'available',
        quantity: -quantity,
        referenceId: entryRef.id,
        sequence: 0,
        ledger: ledger,
      );
      if (bucket != null) {
        _writeMovement(
          transaction,
          movements,
          balanceRef,
          balance,
          type: type,
          bucket: bucket,
          quantity: quantity,
          referenceId: entryRef.id,
          sequence: 1,
          ledger: ledger,
        );
      }
      transaction.set(entryRef, {
        'balanceId': balanceRef.id,
        'itemId': itemId,
        'variantId': variantId,
        'storeId': storeId,
        'batchNumber': batchNumber,
        'quantity': quantity,
        'bucket': bucket,
        'reason': reason,
        'remarks': remarks,
        'evidence': null,
        'referenceType': 'unavailable',
        'referenceId': entryRef.id,
        'status': bucket == null ? 'resolved' : 'open',
        'resolution': bucket == null ? 'write_off' : null,
        'resolvedAt': null,
        'reportedBy': uid,
        ...ledger,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': entryRef.id};
  }

  /// Closes an unavailable-stock entry: restore it, send it to repair, or write it off.
  Future<Map<String, dynamic>> _resolveUnavailable(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = _financialYear;
    final id = data['id']! as String;
    final resolution = data['resolution']! as String;
    final remarks = _blankToNull(data['remarks']);
    if (!const [
      'restore',
      'repair',
      'dispose',
      'write_off',
      'vendor_return',
      'other',
    ].contains(resolution)) {
      _fail('Invalid resolution');
    }
    if (resolution == 'other' && remarks == null) {
      _fail('Describe the resolution');
    }
    if (remarks != null && remarks.length > 500) _fail('Note is too long');

    final entryRef = await _doc('inventoryUnavailableStock/$id');
    final movements = await branchCollection('inventoryMovements');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final entry = (await transaction.get(entryRef)).data();
      if (entry == null) _fail('Entry not found');
      final status = entry['status'];
      final repair = resolution == 'repair';
      final canRepair = status == 'open' && entry['bucket'] == 'damaged';
      if ((status != 'open' && status != 'in_repair') ||
          (repair && !canRepair)) {
        _fail('Entry is $status');
      }
      final bucket = entry['bucket'] as String?;
      final quantity = (entry['quantity'] as num).toDouble();
      DocumentReference<Map<String, dynamic>>? balanceRef;
      Map<String, dynamic>? balance;
      double? reorderLevel;
      if (!repair) {
        final item = await _stockItem(
          transaction,
          entry['itemId']! as String,
          entry['variantId'] as String?,
          inactiveOk: true,
        );
        reorderLevel = (item['reorderLevel'] as num?)?.toDouble();
        balanceRef = await _doc('inventoryBalances/${entry['balanceId']}');
        balance = (await transaction.get(balanceRef)).data();
        if (balance == null) _fail('Balance not found');
        final expiry = readDayOrNull(balance['expiryDate']);
        if (resolution == 'restore' &&
            expiry != null &&
            expiry.compareTo(today) < 0) {
          _fail('Expired batches cannot return to usable stock');
        }
      }

      // Then writes.
      if (!repair) {
        final field = _bucketFields[bucket]!;
        final inBucket = balance![field] as num;
        if (inBucket < quantity) {
          _fail('Insufficient stock ($inBucket $bucket)');
        }
        final restore = resolution == 'restore';
        final available =
            (balance['quantityAvailable'] as num) + (restore ? quantity : 0);
        final unitCost = (balance['unitCost'] as num).toDouble();
        transaction.update(balanceRef!, {
          field: inBucket - quantity,
          'quantityAvailable': available,
          'value': (available * unitCost * 100).round() / 100,
          'isBelowReorderLevel':
              reorderLevel != null && available <= reorderLevel,
          'earliestExpiryDate': available > 0 ? balance['expiryDate'] : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final ledger = <String, Object?>{
          'storeId': entry['storeId'],
          'transactionDate': dayTimestamp(today),
          'financialYear': financialYear,
          'createdBy': uid,
        };
        final type = restore ? 'restore' : 'writeoff';
        _writeMovement(
          transaction,
          movements,
          balanceRef,
          balance,
          type: type,
          bucket: bucket!,
          quantity: -quantity,
          referenceId: id,
          sequence: 0,
          ledger: ledger,
        );
        if (restore) {
          _writeMovement(
            transaction,
            movements,
            balanceRef,
            balance,
            type: type,
            bucket: 'available',
            quantity: quantity,
            referenceId: id,
            sequence: 1,
            ledger: ledger,
          );
        }
      }
      transaction.update(entryRef, {
        'status': repair ? 'in_repair' : 'resolved',
        'resolution': resolution,
        'resolutionNote': remarks,
        if (!repair) ...{
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': uid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// Issues approved stock to a recipient, first-expiry-first-out per line.
  Future<Map<String, dynamic>> _issueStock(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = _financialYear;
    final requestId = data['issueRequestId']! as String;
    final recipient = Map<String, dynamic>.from(data['recipient']! as Map);
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) _fail('Add at least one item');
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      _fail('Each item (and variant) may appear once');
    }
    if (lines.any((line) => ((line['quantity'] as num?) ?? 0) <= 0)) {
      _fail('Each line needs a quantity');
    }

    final requestRef = await _doc('inventoryIssueRequests/$requestId');
    final request = (await requestRef.get()).data();
    if (request == null) _fail('Issue request not found');
    final storeId = request['storeId']! as String;

    final candidateRefs = await _candidateBalances(storeId, lines);

    final counterRef = await _doc('counters/ISS_$financialYear');
    final issueRef = (await branchCollection('inventoryIssues')).doc();
    final movements = await branchCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final current = (await transaction.get(requestRef)).data();
      if (current == null) _fail('Issue request not found');
      final status = current['status'];
      if (status != 'approved' && status != 'partially_issued') {
        _fail('Request is $status');
      }
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;
      final requestLines = [
        for (final line in (current['lineItems'] as List))
          Map<String, dynamic>.from(line as Map),
      ];

      final plans = <_IssuePlan>[];
      for (final line in lines) {
        final itemId = line['itemId']! as String;
        final variantId = line['variantId'] as String?;
        final quantity = (line['quantity']! as num).toDouble();
        final requestLine = requestLines.firstWhere(
          (candidate) =>
              candidate['itemId'] == itemId &&
              candidate['variantId'] == variantId,
          orElse: () => _fail('Item is not on the request'),
        );
        if ((requestLine['quantityIssued'] as num) + quantity >
            (requestLine['quantityApproved'] as num)) {
          _fail('Issue exceeds the approved quantity');
        }
        final item = await _stockItem(
          transaction,
          itemId,
          variantId,
          inactiveOk: true,
        );
        final picks = await _allocateStock(
          transaction,
          candidateRefs['${itemId}__${variantId ?? '-'}']!,
          quantity,
          item['name'],
        );
        plans.add(
          _IssuePlan(
            itemId: itemId,
            variantId: variantId,
            quantity: quantity,
            requestLine: requestLine,
            reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
            picks: picks,
          ),
        );
      }

      // Then writes.
      final issueNumber =
          'ISS/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      var sequence = 0;
      final issuedRows = <Map<String, Object?>>[];
      for (final plan in plans) {
        for (final pick in plan.picks) {
          final balance = pick.balance;
          final unitCost = (balance.data['unitCost'] as num).toDouble();
          _takeStock(
            transaction,
            movements,
            pick,
            type: 'issue',
            referenceType: 'issue',
            referenceId: issueRef.id,
            reorderLevel: plan.reorderLevel,
            sequence: sequence++,
            ledger: {
              'storeId': storeId,
              'transactionDate': dayTimestamp(today),
              'financialYear': financialYear,
              'createdBy': uid,
            },
          );
          issuedRows.add({
            'itemId': plan.itemId,
            'variantId': plan.variantId,
            'balanceId': balance.reference.id,
            'batchNumber': balance.data['batchNumber'],
            'manufacturingDate': balance.data['manufacturingDate'],
            'expiryDate': balance.data['expiryDate'],
            'unitCost': unitCost,
            'quantity': pick.quantity,
            'quantityReturned': 0,
          });
        }
        plan.requestLine['quantityIssued'] =
            (plan.requestLine['quantityIssued'] as num) + plan.quantity;
      }
      final done = requestLines.every(
        (line) =>
            (line['quantityIssued'] as num) >=
            (line['quantityApproved'] as num),
      );
      transaction.set(issueRef, {
        'number': issueNumber,
        'issueRequestId': requestId,
        'storeId': storeId,
        'recipient': recipient,
        'issuedBy': uid,
        'remarks': _blankToNull(data['remarks']),
        'lineItems': issuedRows,
        'itemIds': {for (final plan in plans) plan.itemId}.toList(),
        'acknowledgement': null,
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'lineItems': requestLines,
        'status': done ? 'issued' : 'partially_issued',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return issueNumber;
    });
    return {'id': issueRef.id, 'number': number};
  }
}

class _ReturnPlan {
  _ReturnPlan({
    required this.issueLine,
    required this.reference,
    required this.balance,
    required this.usable,
    required this.damaged,
    required this.reorderLevel,
  });

  final Map<String, dynamic> issueLine;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> balance;
  final double usable;
  final double damaged;
  final double? reorderLevel;
}

class _IssueBalance {
  _IssueBalance(this.reference, this.data, this.expiry);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;
  final String? expiry;

  double get quantityAvailable => (data['quantityAvailable'] as num).toDouble();
}

class _IssuePick {
  _IssuePick(this.balance, this.quantity);

  final _IssueBalance balance;
  final double quantity;
}

class _IssuePlan {
  _IssuePlan({
    required this.itemId,
    required this.variantId,
    required this.quantity,
    required this.requestLine,
    required this.reorderLevel,
    required this.picks,
  });

  final String itemId;
  final String? variantId;
  final double quantity;
  final Map<String, dynamic> requestLine;
  final double? reorderLevel;
  final List<_IssuePick> picks;
}

class _ReceiptLine {
  _ReceiptLine({
    required this.itemId,
    required this.variantId,
    required this.batchNumber,
    required this.expiryDate,
    required this.accepted,
    required this.rejected,
    required this.unitCost,
    required this.condition,
    required this.reorderLevel,
    required this.balanceId,
    required this.balanceRef,
    required this.balance,
  });

  final String itemId;
  final String? variantId;
  final String? batchNumber;
  final String? expiryDate;
  final double accepted;
  final double rejected;
  final double unitCost;
  final String? condition;
  final double? reorderLevel;
  final String balanceId;
  final DocumentReference<Map<String, dynamic>> balanceRef;
  final Map<String, dynamic>? balance;
}
