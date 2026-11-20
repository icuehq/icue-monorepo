import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/stock_support.dart';

/// Returns of issued stock.
class ReturnWrites with StockSupport {
  /// Takes back issued stock: usable units return to the balance they came from,
  /// damaged ones go to the damaged bucket and the unavailable-stock register.
  Future<Map<String, dynamic>> createReturn(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = currentFinancialYear;
    final issueId = data['issueId']! as String;
    final returnedBy = Map<String, dynamic>.from(data['returnedBy']! as Map);
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) failWith('Add at least one item');
    if ({for (final line in lines) line['balanceId']}.length != lines.length) {
      failWith('Each line may appear once');
    }

    final issueRef = await branchDoc('inventoryIssues/$issueId');
    final counterRef = await branchDoc('counters/RET_$financialYear');
    final returnRef = (await branchCollection('inventoryReturns')).doc();
    final movements = await branchCollection('inventoryMovements');
    final unavailable = await branchCollection('inventoryUnavailableStock');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final issue = (await transaction.get(issueRef)).data();
      if (issue == null) failWith('Issue not found');
      final storeId = issue['storeId']! as String;
      final store = (await transaction.get(
        await branchDoc('inventoryStores/$storeId'),
      )).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');
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
          orElse: () => failWith('Line is not on the issue'),
        );
        if (usable < 0 || damaged < 0 || quantity <= 0) {
          failWith('Each line needs a quantity');
        }
        final outstanding =
            (issueLine['quantity'] as num) -
            (issueLine['quantityReturned'] as num);
        if (quantity > outstanding) {
          failWith('Only $outstanding outstanding for this line');
        }
        final item = await activeStockItem(
          transaction,
          issueLine['itemId']! as String,
          issueLine['variantId'] as String?,
          inactiveOk: true,
        );
        final reference = await branchDoc(
          'inventoryBalances/${line['balanceId']}',
        );
        final balance = (await transaction.get(reference)).data();
        if (balance == null) {
          failWith('No stock of ${item['name']} in this store');
        }
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
            'lastWrite': writeStamp('inventoryUnavailable.report'),
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
        'remarks': blankToNullText(data['remarks']),
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
        'lastWrite': writeStamp('inventoryReturn.create'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(issueRef, {
        'lineItems': issueLines,
        'lastWrite': writeStamp('inventoryIssue.return'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return returnNumber;
    });
    return {'id': returnRef.id, 'number': number};
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
