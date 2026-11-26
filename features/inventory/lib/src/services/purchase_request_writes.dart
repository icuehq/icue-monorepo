import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/procurement_support.dart';
import 'package:inventory/src/services/stock_support.dart';

/// `open` until anything arrives, `received` once every line is fully accounted for
/// (good + damaged), `partially_received` in between. Mirrored in `firebase/functions/src/inventory/assets.ts`.
String purchaseRequestStatus(Iterable<Map<String, dynamic>> lines) {
  var anyArrived = false;
  var allArrived = true;
  for (final line in lines) {
    final arrived =
        (line['received'] as num? ?? 0) + (line['damaged'] as num? ?? 0);
    if (arrived > 0) anyArrived = true;
    if (arrived < (line['quantity'] as num)) allArrived = false;
  }
  return allArrived
      ? PurchaseRequestStatus.received
      : anyArrived
      ? PurchaseRequestStatus.partiallyReceived
      : PurchaseRequestStatus.open;
}

/// Purchase requests: no approval. Created by store staff, filled offline, and the goods
/// recorded on the request as they arrive (each receipt adds them to the store's stock).
class PurchaseRequestWrites with ProcurementSupport, StockSupport {
  /// Creates a request, or edits one ([data] `id`) while nothing has been received. The store never changes.
  Future<Map<String, dynamic>> savePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final requiredDate = data['requiredDate']! as String;
    if (requiredDate.compareTo(todayDay) < 0) {
      failWith('Required date is in the past');
    }
    final lines = asLines(data['lineItems']);
    if (lines.isEmpty) failWith('Add at least one item');
    requireUniqueLines(lines);
    final storedLines = [
      for (final line in lines)
        {
          'itemId': line['itemId'],
          'variantId': line['variantId'],
          'quantity': line['quantity'],
          'received': 0,
          'damaged': 0,
        },
    ];
    final fields = {
      'requiredDate': dayTimestamp(requiredDate),
      'priority': data['priority'] ?? 'normal',
      'purpose': (data['purpose']! as String).trim(),
      'remarks': blankToNullText(data['remarks']),
      'lineItems': storedLines,
      'itemIds': {for (final line in storedLines) line['itemId']}.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await loadDocument(
        'inventoryPurchaseRequests',
        id,
        'Purchase request',
      );
      if (existing['status'] != PurchaseRequestStatus.open) {
        failWith('Goods have been received; this request can no longer change');
      }
      await _requireStoreItems(existing['storeId']! as String, storedLines);
      await reference.update({
        ...fields,
        'history': [...(existing['history'] as List), historyEntry('update')],
        'lastWrite': writeStamp('inventoryPurchaseRequest.update'),
      });
      return {'id': id, 'number': existing['number']};
    }
    final storeId = data['storeId']! as String;
    await _requireStoreItems(storeId, storedLines);
    final number = await nextNumber('PR');
    final reference = (await branchCollection('inventoryPurchaseRequests'))
        .doc();
    await reference.set({
      ...fields,
      'number': number,
      'storeId': storeId,
      'status': PurchaseRequestStatus.open,
      'history': [historyEntry('create')],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
      'lastWrite': writeStamp('inventoryPurchaseRequest.create'),
    });
    return {'id': reference.id, 'number': number};
  }

  /// Every line's item belongs to [storeId].
  Future<void> _requireStoreItems(
    String storeId,
    List<Map<String, dynamic>> lines,
  ) async {
    final items = await branchCollection('inventoryItems');
    for (final line in lines) {
      final item = (await items.doc(line['itemId']! as String).get()).data();
      if (item == null) failWith('Item not found');
      if (item['storeId'] != storeId) {
        failWith('${item['name']} belongs to another store');
      }
    }
  }

  /// Records goods that arrived for stock lines ([data] `lineItems`: itemId, variantId, received,
  /// damaged, batchNumber, expiryDate) and adds them to the store in one transaction:
  /// good units to available stock at the item's default price, damaged ones to its damaged stock, each with a
  /// `receive` ledger row. Asset lines go through
  /// `inventory.asset.receive` with the request's ID instead.
  Future<Map<String, dynamic>> receivePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final today = todayIST();
    final requestRef = await branchReference(
      'inventoryPurchaseRequests',
      data['id']! as String,
    );
    final receipts = asLines(data['lineItems']);
    if (receipts.isEmpty) failWith('Enter what was received');
    final movements = await branchCollection('inventoryMovements');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final request = (await transaction.get(requestRef)).data();
      if (request == null) failWith('Purchase request not found');
      if (!openPurchaseRequestStatuses.contains(request['status'])) {
        failWith('This purchase request is ${request['status']}');
      }
      final storeId = request['storeId']! as String;
      final store = (await transaction.get(
        await branchDoc('inventoryStores/$storeId'),
      )).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');

      final lines = asLines(request['lineItems']);
      final changes = <_Arrival>[];
      final summary = <String>[];
      final balanceIds = <String>{};
      for (final receipt in receipts) {
        final itemId = receipt['itemId']! as String;
        final variantId = receipt['variantId'] as String?;
        final line = lines
            .where((line) => lineKey(line) == lineKey(receipt))
            .firstOrNull;
        if (line == null) failWith('Item is not on this request');
        final good = (receipt['received'] as num? ?? 0).toDouble();
        final damaged = (receipt['damaged'] as num? ?? 0).toDouble();
        if (good < 0 || damaged < 0) failWith('Quantities cannot be negative');
        if (good + damaged == 0) continue;
        final item = await activeStockItem(transaction, itemId, variantId);
        final pending =
            ((line['quantity'] as num) -
                    (line['received'] as num? ?? 0) -
                    (line['damaged'] as num? ?? 0))
                .toDouble();
        if (good + damaged > pending) {
          failWith('${item['name']}: only ${pending.toQuantityText()} pending');
        }

        String? batchNumber;
        String? expiryDate;
        if (item['tracking'] == 'batch') {
          batchNumber = blankToNullText(receipt['batchNumber']);
          if (batchNumber == null) {
            failWith('${item['name']} needs a batch number');
          }
          expiryDate = blankToNullText(receipt['expiryDate']);
          if (expiryDate != null && expiryDate.compareTo(today) < 0) {
            failWith('Expired batches cannot be received');
          }
        }
        final balanceId = [
          storeId,
          itemId,
          variantId ?? '-',
          batchNumber == null ? '-' : Uri.encodeComponent(batchNumber),
        ].join('__');
        if (!balanceIds.add(balanceId)) {
          failWith('Each item, variant and batch may appear once');
        }
        final balanceRef = await branchDoc('inventoryBalances/$balanceId');
        changes.add(
          _Arrival(
            line: line,
            itemId: itemId,
            variantId: variantId,
            good: good,
            damaged: damaged,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            unitCost: (item['defaultPrice'] as num?)?.toDouble() ?? 0,
            reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
            balanceRef: balanceRef,
            balance: (await transaction.get(balanceRef)).data(),
          ),
        );
        summary.add(
          '${item['name']}: ${good.toQuantityText()} received'
          '${damaged > 0 ? ', ${damaged.toQuantityText()} damaged' : ''}',
        );
      }
      if (changes.isEmpty) failWith('Enter what was received');

      // Then writes.
      final ledger = <String, Object?>{
        'storeId': storeId,
        'transactionDate': dayTimestamp(today),
        'financialYear': currentFinancialYear,
        'createdBy': currentUid,
      };
      for (final (index, change) in changes.indexed) {
        addStock(
          transaction,
          movements,
          reference: change.balanceRef,
          balance: change.balance,
          storeId: storeId,
          itemId: change.itemId,
          variantId: change.variantId,
          batchNumber: change.batchNumber,
          expiryDate: change.expiryDate,
          quantity: change.good,
          damaged: change.damaged,
          unitCost: change.unitCost,
          reorderLevel: change.reorderLevel,
          type: 'receive',
          referenceType: 'purchaseRequest',
          referenceId: requestRef.id,
          sequence: index * 2,
          ledger: ledger,
        );
        change.line['received'] =
            (change.line['received'] as num? ?? 0) + change.good;
        change.line['damaged'] =
            (change.line['damaged'] as num? ?? 0) + change.damaged;
      }
      transaction.update(requestRef, {
        'lineItems': lines,
        'status': purchaseRequestStatus(lines),
        'history': [
          ...(request['history'] as List),
          historyEntry('receive', summary.join('; ')),
        ],
        'lastWrite': writeStamp('inventoryPurchaseRequest.receive'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return {'id': requestRef.id, 'number': request['number']};
    });
  }

  /// Closes a request whose remaining goods will not come; what arrived stays in stock.
  Future<Map<String, dynamic>> closePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await loadDocument(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    if (!openPurchaseRequestStatuses.contains(request['status'])) {
      failWith('This purchase request is ${request['status']}');
    }
    final reason = blankToNullText(data['reason']);
    await reference.update({
      'status': PurchaseRequestStatus.closed,
      'history': [
        ...(request['history'] as List),
        historyEntry('close', reason),
      ],
      'lastWrite': writeStamp('inventoryPurchaseRequest.close', reason),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }
}

class _Arrival {
  _Arrival({
    required this.line,
    required this.itemId,
    required this.variantId,
    required this.good,
    required this.damaged,
    required this.batchNumber,
    required this.expiryDate,
    required this.unitCost,
    required this.reorderLevel,
    required this.balanceRef,
    required this.balance,
  });

  final Map<String, dynamic> line;
  final String itemId;
  final String? variantId;
  final double good;
  final double damaged;
  final String? batchNumber;
  final String? expiryDate;
  final double unitCost;
  final double? reorderLevel;
  final DocumentReference<Map<String, dynamic>> balanceRef;
  final Map<String, dynamic>? balance;
}
