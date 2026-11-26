import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/stock_support.dart';

/// Issue requests (submit, decide, cancel, close), issuing stock and acknowledging an issue.
class IssueWrites with StockSupport {
  /// Raises a pending issue request for items of one store and one top-level category; that category's approvers decide it on the Requests screen.
  Future<Map<String, dynamic>> submitIssueRequest(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final storeId = data['storeId']! as String;
    final categoryId = data['categoryId']! as String;
    final purpose = blankToNullText(data['purpose']);
    if (purpose == null) failWith('Enter the purpose of the request');
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) failWith('Add at least one item');
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      failWith('Each item (and variant) may appear once');
    }
    for (final line in lines) {
      if ((line['quantity'] as num) <= 0) {
        failWith('Enter a quantity for every item');
      }
    }

    final financialYear = currentFinancialYear;
    final counterRef = await branchDoc('counters/IR_$financialYear');
    final requestRef = (await branchCollection('inventoryIssueRequests')).doc();
    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final store = (await transaction.get(
        await branchDoc('inventoryStores/$storeId'),
      )).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');
      for (final line in lines) {
        final item = await activeStockItem(
          transaction,
          line['itemId'] as String,
          line['variantId'] as String?,
          assetOk: true,
        );
        if (item['storeId'] != storeId) {
          failWith('${item['name']} does not belong to this store');
        }
        if (item['categoryId'] != categoryId) {
          failWith('${item['name']} does not belong to this category');
        }
      }
      final next =
          ((await transaction.get(counterRef)).data()?['next'] as num? ?? 0)
              .toInt() +
          1;
      final requestNumber =
          'IR/$financialYear/${next.toString().padLeft(6, '0')}';
      transaction.set(counterRef, {
        'next': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(requestRef, {
        'number': requestNumber,
        'storeId': storeId,
        'categoryId': categoryId,
        'purpose': purpose,
        'destination': blankToNullText(data['destination']),
        'status': 'pending',
        'createdBy': uid,
        'requesterName': blankToNullText(data['requesterName']),
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('inventoryIssueRequest.submit'),
      });
      return requestNumber;
    });
    return {'id': requestRef.id, 'number': number};
  }

  Future<Map<String, dynamic>> decideIssueRequest(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = data['id']! as String;
    final approve = data['decision'] == 'approve';
    final comment = blankToNullText(data['comment']);
    if (!approve && comment == null) failWith('A reason is required to reject');
    final overrides = {
      for (final line in (data['lineItems'] as List? ?? const []))
        (line as Map)['index'] as int: (line['quantityApproved'] as num)
            .toDouble(),
    };

    final reference = await branchDoc('inventoryIssueRequests/$id');
    final current = (await reference.get()).data();
    if (current == null) failWith('Issue request not found');
    final approvedLines = <Map<String, dynamic>>[];
    if (approve) {
      final lines = (current['lineItems'] as List).cast<Map<String, dynamic>>();
      for (final (index, line) in lines.indexed) {
        final requested = (line['quantityRequested'] as num).toDouble();
        final approved = overrides[index] ?? requested;
        if (approved > requested) {
          failWith('Approved quantity exceeds the request');
        }
        final storeId = current['storeId'] as String;
        final itemId = line['itemId'] as String;
        final item = (await (await branchDoc(
          'inventoryItems/$itemId',
        )).get()).data();
        final available = item?['tracking'] == 'asset'
            ? await availableAssets(storeId, itemId)
            : await availableStock(
                storeId,
                itemId,
                line['variantId'] as String?,
              );
        if (approved > 0 && approved > available) {
          failWith('Approved quantity exceeds available stock');
        }
        approvedLines.add({...line, 'quantityApproved': approved});
      }
      if (!approvedLines.any((line) => (line['quantityApproved'] as num) > 0)) {
        failWith('Nothing approved; reject the request instead');
      }
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final status = (await transaction.get(reference)).data()?['status'];
      if (status != 'pending') failWith('Request is already $status');
      transaction.update(reference, {
        'status': approve ? 'approved' : 'rejected',
        'lineItems': ?(approve ? approvedLines : null),
        'approval': {
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
          'comment': comment,
        },
        'lastWrite': writeStamp(
          approve
              ? 'inventoryIssueRequest.approve'
              : 'inventoryIssueRequest.reject',
          comment,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// The requester withdraws a pending request (`cancel`), or a stock operator closes what is
  /// still outstanding on an approved / partly issued one (`close`). Either needs a reason.
  Future<Map<String, dynamic>> endIssueRequest(
    Map<String, Object?> data, {
    required bool cancel,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = data['id']! as String;
    final reason = blankToNullText(data['reason']);
    if (reason == null) failWith('A reason is required');
    final reference = await branchDoc('inventoryIssueRequests/$id');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final request = (await transaction.get(reference)).data();
      if (request == null) failWith('Issue request not found');
      final status = request['status'];
      if (cancel
          ? status != 'pending' || request['createdBy'] != uid
          : status != 'approved' && status != 'partially_issued') {
        failWith('Request is $status');
      }
      transaction.update(reference, {
        'status': cancel ? 'cancelled' : 'closed',
        'closure': {
          'performedBy': uid,
          'performedAt': FieldValue.serverTimestamp(),
          'reason': reason,
        },
        'lastWrite': writeStamp(
          cancel
              ? 'inventoryIssueRequest.cancel'
              : 'inventoryIssueRequest.close',
          reason,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// The recipient's receipt of an issue is confirmed once.
  Future<Map<String, dynamic>> acknowledgeIssue(
    Map<String, Object?> data,
  ) async {
    final id = data['id']! as String;
    final reference = await branchDoc('inventoryIssues/$id');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final issue = (await transaction.get(reference)).data();
      if (issue == null) failWith('Issue not found');
      if (issue['acknowledgement'] != null) failWith('Already acknowledged');
      transaction.update(reference, {
        'acknowledgement': {
          'performedBy': FirebaseAuth.instance.currentUser!.uid,
          'performedAt': FieldValue.serverTimestamp(),
          'remarks': blankToNullText(data['remarks']),
        },
        'lastWrite': writeStamp('inventoryIssue.acknowledge'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }

  /// Issues approved stock to a recipient, first-expiry-first-out per line.
  Future<Map<String, dynamic>> issueStock(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = currentFinancialYear;
    final requestId = data['issueRequestId']! as String;
    final recipient = Map<String, dynamic>.from(data['recipient']! as Map);
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) failWith('Add at least one item');
    final lineKeys = {
      for (final line in lines)
        '${line['itemId']}__${line['variantId'] ?? '-'}',
    };
    if (lineKeys.length != lines.length) {
      failWith('Each item (and variant) may appear once');
    }
    if (lines.any((line) => ((line['quantity'] as num?) ?? 0) <= 0)) {
      failWith('Each line needs a quantity');
    }

    final requestRef = await branchDoc('inventoryIssueRequests/$requestId');
    final request = (await requestRef.get()).data();
    if (request == null) failWith('Issue request not found');
    final storeId = request['storeId']! as String;

    final candidateRefs = await findCandidateBalances(storeId, lines);

    final counterRef = await branchDoc('counters/ISS_$financialYear');
    final issueRef = (await branchCollection('inventoryIssues')).doc();
    final movements = await branchCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final current = (await transaction.get(requestRef)).data();
      if (current == null) failWith('Issue request not found');
      final status = current['status'];
      if (status != 'approved' && status != 'partially_issued') {
        failWith('Request is $status');
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
          orElse: () => failWith('Item is not on the request'),
        );
        if ((requestLine['quantityIssued'] as num) + quantity >
            (requestLine['quantityApproved'] as num)) {
          failWith('Issue exceeds the approved quantity');
        }
        final item = await activeStockItem(
          transaction,
          itemId,
          variantId,
          inactiveOk: true,
        );
        final picks = await allocateStock(
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
          takeStock(
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
        'remarks': blankToNullText(data['remarks']),
        'lineItems': issuedRows,
        'itemIds': {for (final plan in plans) plan.itemId}.toList(),
        'acknowledgement': null,
        'transactionDate': dayTimestamp(today),
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'lastWrite': writeStamp('inventoryIssue.create'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'lineItems': requestLines,
        'status': done ? 'issued' : 'partially_issued',
        'lastWrite': writeStamp('inventoryIssueRequest.issue'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return issueNumber;
    });
    return {'id': issueRef.id, 'number': number};
  }
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
  final List<IssuePick> picks;
}
