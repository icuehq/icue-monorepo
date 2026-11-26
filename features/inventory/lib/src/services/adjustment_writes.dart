import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/stock_support.dart';

/// Stock adjustments and the unavailable-stock register (report, resolve).
class AdjustmentWrites with StockSupport {
  static const _adjustmentReasons = [
    'count_correction',
    'data_entry',
    'missing',
    'excess',
    'other',
  ];

  /// A manual correction of one balance's available quantity, with a reason.
  Future<Map<String, dynamic>> adjustStock(Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = currentFinancialYear;
    final storeId = data['storeId']! as String;
    final itemId = data['itemId']! as String;
    final variantId = data['variantId'] as String?;
    final batchNumber = blankToNullText(data['batchNumber']);
    final delta = (data['delta']! as num).toDouble();
    final reason = data['reason']! as String;
    final remarks = blankToNullText(data['remarks']);
    if (delta == 0 || delta.abs() > 1000000) {
      failWith('Quantity change must not be 0');
    }
    if (!_adjustmentReasons.contains(reason)) failWith('Invalid reason');
    if (reason == 'other' && remarks == null) failWith('Describe the reason');
    if (remarks != null && remarks.length > 500) failWith('Note is too long');
    if ((reason == 'missing' && delta > 0) ||
        (reason == 'excess' && delta < 0)) {
      failWith('Reason does not match the direction');
    }

    final storeRef = await branchDoc('inventoryStores/$storeId');
    final balanceRef = await branchDoc(
      'inventoryBalances/${[storeId, itemId, variantId ?? '-', batchNumber == null ? '-' : Uri.encodeComponent(batchNumber)].join('__')}',
    );
    final counterRef = await branchDoc('counters/ADJ_$financialYear');
    final adjustmentRef = (await branchCollection('inventoryAdjustments'))
        .doc();
    final movements = await branchCollection('inventoryMovements');

    final number = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');
      final item = await activeStockItem(transaction, itemId, variantId);
      final balance = (await transaction.get(balanceRef)).data();
      if (balance == null) {
        failWith('No stock of ${item['name']} in this store');
      }
      final before = (balance['quantityAvailable'] as num).toDouble();
      if (before + delta < 0) {
        failWith('Insufficient stock ($before available)');
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
      takeStock(
        transaction,
        movements,
        IssuePick(
          IssueBalance(
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
        'lastWrite': writeStamp('inventoryAdjustment.create'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return adjustmentNumber;
    });
    return {'id': adjustmentRef.id, 'number': number};
  }

  /// Moves usable stock out of `quantityAvailable` into the unavailable-stock register.
  Future<Map<String, dynamic>> reportUnavailable(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = currentFinancialYear;
    final storeId = data['storeId']! as String;
    final itemId = data['itemId']! as String;
    final variantId = data['variantId'] as String?;
    final batchNumber = blankToNullText(data['batchNumber']);
    final quantity = (data['quantity']! as num).toDouble();
    final reason = data['reason']! as String;
    final remarks = blankToNullText(data['remarks']);
    if (quantity <= 0) failWith('Enter a quantity');
    if (!const ['damaged', 'expired', 'lost'].contains(reason)) {
      failWith('Invalid reason');
    }
    if (remarks == null || remarks.length > 500) {
      failWith('Details are required (500 characters at most)');
    }
    final bucket = reason == 'lost' ? null : reason;

    final storeRef = await branchDoc('inventoryStores/$storeId');
    final balanceRef = await branchDoc(
      'inventoryBalances/${[storeId, itemId, variantId ?? '-', batchNumber == null ? '-' : Uri.encodeComponent(batchNumber)].join('__')}',
    );
    final entryRef = (await branchCollection('inventoryUnavailableStock'))
        .doc();
    final movements = await branchCollection('inventoryMovements');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');
      final item = await activeStockItem(
        transaction,
        itemId,
        variantId,
        inactiveOk: true,
      );
      final balance = (await transaction.get(balanceRef)).data();
      if (balance == null) {
        failWith('No stock of ${item['name']} in this store');
      }
      final expiry = readDayOrNull(balance['expiryDate']);
      if (reason == 'expired' &&
          (expiry == null || expiry.compareTo(today) >= 0)) {
        failWith('Batch has not expired');
      }
      final available = (balance['quantityAvailable'] as num) - quantity;
      if (available < 0) {
        failWith(
          'Insufficient stock (${balance['quantityAvailable']} available)',
        );
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
          StockSupport.bucketFields[bucket]!:
              (balance[StockSupport.bucketFields[bucket]] as num) + quantity,
        'value': (available * unitCost * 100).round() / 100,
        'isBelowReorderLevel':
            reorderLevel != null && available <= reorderLevel,
        'earliestExpiryDate': available > 0 ? balance['expiryDate'] : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writeMovement(
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
        writeMovement(
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
        'lastWrite': writeStamp('inventoryUnavailable.report'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': entryRef.id};
  }

  /// Closes an unavailable-stock entry: restore it, send it to repair, or write it off.
  Future<Map<String, dynamic>> resolveUnavailable(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = todayIST();
    final financialYear = currentFinancialYear;
    final id = data['id']! as String;
    final resolution = data['resolution']! as String;
    final remarks = blankToNullText(data['remarks']);
    if (!const [
      'restore',
      'repair',
      'dispose',
      'write_off',
      'vendor_return',
      'other',
    ].contains(resolution)) {
      failWith('Invalid resolution');
    }
    if (resolution == 'other' && remarks == null) {
      failWith('Describe the resolution');
    }
    if (remarks != null && remarks.length > 500) failWith('Note is too long');

    final entryRef = await branchDoc('inventoryUnavailableStock/$id');
    final movements = await branchCollection('inventoryMovements');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final entry = (await transaction.get(entryRef)).data();
      if (entry == null) failWith('Entry not found');
      final status = entry['status'];
      final repair = resolution == 'repair';
      final canRepair = status == 'open' && entry['bucket'] == 'damaged';
      if ((status != 'open' && status != 'in_repair') ||
          (repair && !canRepair)) {
        failWith('Entry is $status');
      }
      final bucket = entry['bucket'] as String?;
      final quantity = (entry['quantity'] as num).toDouble();
      DocumentReference<Map<String, dynamic>>? balanceRef;
      Map<String, dynamic>? balance;
      double? reorderLevel;
      if (!repair) {
        final item = await activeStockItem(
          transaction,
          entry['itemId']! as String,
          entry['variantId'] as String?,
          inactiveOk: true,
        );
        reorderLevel = (item['reorderLevel'] as num?)?.toDouble();
        balanceRef = await branchDoc('inventoryBalances/${entry['balanceId']}');
        balance = (await transaction.get(balanceRef)).data();
        if (balance == null) failWith('Balance not found');
        final expiry = readDayOrNull(balance['expiryDate']);
        if (resolution == 'restore' &&
            expiry != null &&
            expiry.compareTo(today) < 0) {
          failWith('Expired batches cannot return to usable stock');
        }
      }

      // Then writes.
      if (!repair) {
        final field = StockSupport.bucketFields[bucket]!;
        final inBucket = balance![field] as num;
        if (inBucket < quantity) {
          failWith('Insufficient stock ($inBucket $bucket)');
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
        writeMovement(
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
          writeMovement(
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
        'lastWrite': writeStamp('inventoryUnavailable.resolve'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': id};
  }
}
