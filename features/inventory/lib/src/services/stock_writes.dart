import 'package:icue_firebase/icue_firebase.dart';

/// Client-side stock writes: Receive Stock (`inventory-receipt-confirm`) issue request submit and approve/reject.
///
/// One Firestore transaction writes the receipt, its balances, the ledger rows
/// and the GRN counter. Business checks live here and in `firestore.rules`
/// (campus + `inventory.stock.operate`). There is no audit log, no low-stock
/// notification and no retry idempotency.
class StockWrites {
  /// Action names `StockProvider.act` routes here instead of to a callable.
  static const names = {
    'inventory-receipt-confirm',
    'inventory-issueRequest-submit',
    'inventory-issueRequest-decide',
    'inventory-issueRequest-cancel',
    'inventory-issueRequest-close',
  };

  static const _sources = [
    'opening',
    'adjustment',
    'department_return',
    'person_return',
    'other',
  ];

  Future<Map<String, dynamic>> run(String name, Map<String, Object?> data) =>
      switch (name) {
        'inventory-receipt-confirm' => _confirmReceipt(data),
        'inventory-issueRequest-submit' => _submitIssueRequest(data),
        'inventory-issueRequest-decide' => _decideIssueRequest(data),
        'inventory-issueRequest-cancel' => _endIssueRequest(data, cancel: true),
        'inventory-issueRequest-close' => _endIssueRequest(data, cancel: false),
        _ => throw ArgumentError.value(name, 'name'),
      };

  Never _fail(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );

  DateTime get _istNow =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  String? _blankToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// `collection/id[/sub/id]` under the school.
  Future<DocumentReference<Map<String, dynamic>>> _doc(String path) async {
    final segments = path.split('/');
    return (await schoolCollection(segments.first))
        .doc(segments.skip(1).join('/'));
  }

  /// Active, stock-tracked item whose variant requirement matches [variantId].
  Future<Map<String, dynamic>> _stockItem(
    Transaction transaction,
    String itemId,
    String? variantId,
  ) async {
    final item = (await transaction.get(await _doc('inventoryItems/$itemId')))
        .data();
    if (item == null) _fail('Item not found');
    final name = item['name'];
    if (item['status'] != 'active') _fail('$name is inactive');
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
      if (variant['status'] != 'active') _fail('Variant is inactive');
    }
    return item;
  }

  String get _financialYear {
    final now = _istNow;
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
  }

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
    if (current['createdBy'] == uid) {
      _fail('A different user must decide on your request');
    }
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
                  current['campusId'] as int,
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
    int campusId,
    String storeId,
    String itemId,
    String? variantId,
  ) async {
    final today = _istNow.toIso8601String().substring(0, 10);
    try {
      final snapshot = await (await schoolCollection('inventoryBalances'))
          .where('campusId', isEqualTo: campusId)
          .where('storeId', isEqualTo: storeId)
          .where('itemId', isEqualTo: itemId)
          .get();
      return snapshot.docs
          .map((document) => document.data())
          .where(
            (balance) =>
                balance['variantId'] == variantId &&
                ((balance['expiryDate'] as String?)?.compareTo(today) ?? 1) >=
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
    final requestRef = (await schoolCollection('inventoryIssueRequests')).doc();
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
        'departmentId': data['departmentId'],
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
        'campusId': store['campusId'],
        'transactionDate': _istNow.toIso8601String().substring(0, 10),
        'financialYear': financialYear,
        'academicYearId': null,
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
    final now = _istNow;
    final today = now.toIso8601String().substring(0, 10);
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
    final receiptRef = (await schoolCollection('inventoryReceipts')).doc();
    final movements = await schoolCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) _fail('Store not found');
      if (store['status'] != 'active') _fail('Store is inactive');
      final campusId = store['campusId'];

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
      final academicYearId = data['academicYearId'];
      var sequence = 0;
      for (final line in prepared) {
        if (line.accepted <= 0) continue;
        final balance = line.balance;
        final have = (balance?['quantityAvailable'] as num? ?? 0).toDouble();
        final cost = (balance?['unitCost'] as num? ?? 0).toDouble();
        final available = have + line.accepted;
        final unitCost =
            (have * cost + line.accepted * line.unitCost) / available;
        final storedExpiry = balance?['expiryDate'] as String?;
        if (storedExpiry != null &&
            line.expiryDate != null &&
            storedExpiry != line.expiryDate) {
          _fail(
            'Batch ${line.batchNumber} already exists with expiry $storedExpiry',
          );
        }
        final expiry = storedExpiry ?? line.expiryDate;
        transaction.set(line.balanceRef, {
          'campusId': campusId,
          'storeId': storeId,
          'itemId': line.itemId,
          'variantId': line.variantId,
          'batchNumber': line.batchNumber,
          'manufacturingDate': balance?['manufacturingDate'],
          'expiryDate': expiry,
          'quantityAvailable': available,
          'quantityReserved': balance?['quantityReserved'] ?? 0,
          'quantityDamaged': balance?['quantityDamaged'] ?? 0,
          'quantityExpired': balance?['quantityExpired'] ?? 0,
          'totalQuantityReceived':
              (balance?['totalQuantityReceived'] as num? ?? 0) + line.accepted,
          'totalQuantityIssued': balance?['totalQuantityIssued'] ?? 0,
          'unitCost': unitCost,
          'value': (available * unitCost * 100).round() / 100,
          'isBelowReorderLevel':
              line.reorderLevel != null && available <= line.reorderLevel!,
          'earliestExpiryDate': expiry,
          'createdAt': balance?['createdAt'] ?? FieldValue.serverTimestamp(),
          'createdBy': balance?['createdBy'] ?? uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(movements.doc(), {
          'type': 'receive',
          'balanceId': line.balanceId,
          'itemId': line.itemId,
          'variantId': line.variantId,
          'storeId': storeId,
          'campusId': campusId,
          'batchNumber': line.batchNumber,
          'quantity': line.accepted,
          'bucket': 'available',
          'referenceType': 'receipt',
          'referenceId': receiptRef.id,
          'unitCost': line.unitCost,
          'transactionDate': today,
          'financialYear': financialYear,
          'academicYearId': academicYearId,
          'seq': sequence++,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
        });
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
              'expiryDate': line.expiryDate,
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
        'campusId': campusId,
        'transactionDate': today,
        'financialYear': financialYear,
        'academicYearId': academicYearId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return grnNumber;
    });
    return {'id': receiptRef.id, 'number': number};
  }
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
