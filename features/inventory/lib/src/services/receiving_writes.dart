import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/stock_support.dart';

/// Receive Stock and receiving goods against a purchase order.
class ReceivingWrites with StockSupport {
  /// Receive Stock: adds each line straight to its store balance (no receipt, ledger row or number).
  Future<Map<String, dynamic>> confirmReceipt(Map<String, Object?> data) async {
    final today = todayIST();
    final storeId = data['storeId']! as String;
    final lines = [
      for (final line in (data['lineItems']! as List))
        Map<String, dynamic>.from(line as Map),
    ];
    if (lines.isEmpty) failWith('Add at least one item');
    final storeRef = await branchDoc('inventoryStores/$storeId');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // All reads first.
      final store = (await transaction.get(storeRef)).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');

      final prepared = <_ReceiptLine>[];
      final balanceIds = <String>{};
      for (final line in lines) {
        final itemId = line['itemId']! as String;
        final variantId = line['variantId'] as String?;
        final item = await activeStockItem(transaction, itemId, variantId);
        final quantity = (line['quantityAccepted'] as num? ?? 0).toDouble();
        if (quantity <= 0) failWith('Each line needs a quantity');

        String? batchNumber;
        String? expiryDate;
        if (item['tracking'] == 'batch') {
          batchNumber = blankToNullText(line['batchNumber']);
          if (batchNumber == null) {
            failWith('${item['name']} needs a batch number');
          }
          expiryDate = blankToNullText(line['expiryDate']);
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
        prepared.add(
          _ReceiptLine(
            itemId: itemId,
            variantId: variantId,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            accepted: quantity,
            rejected: 0,
            unitCost:
                (line['unitCost'] as num?)?.toDouble() ??
                (item['defaultPrice'] as num?)?.toDouble() ??
                0,
            condition: null,
            reorderLevel: (item['reorderLevel'] as num?)?.toDouble(),
            balanceId: balanceId,
            balanceRef: balanceRef,
            balance: (await transaction.get(balanceRef)).data(),
          ),
        );
      }

      // Then writes.
      for (final line in prepared) {
        setBalance(
          transaction,
          line.balanceRef,
          line.balance,
          storeId: storeId,
          itemId: line.itemId,
          variantId: line.variantId,
          batchNumber: line.batchNumber,
          expiryDate: line.expiryDate,
          quantity: line.accepted,
          unitCost: line.unitCost,
          reorderLevel: line.reorderLevel,
        );
      }
    });
    return {'id': storeId};
  }

  /// One delivery against a PO. Accepted quantity enters the store at the PO unit price;
  /// rejected quantity is recorded but never becomes stock; asset units are counted on the
  /// order but never enter stock either (each is registered individually). Unit cost
  /// excludes PO discount, tax and delivery.
  Future<Map<String, dynamic>> receivePurchaseOrder(
    Map<String, Object?> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now().toIndianTime().toApiDate();
    final financialYear = currentFinancialYear;
    final storeId = data['storeId']! as String;
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

    final orderRef = await branchDoc(
      'inventoryPurchaseOrders/${data['purchaseOrderId']}',
    );
    final storeRef = await branchDoc('inventoryStores/$storeId');
    final counterRef = await branchDoc('counters/GRN_$financialYear');
    final receiptRef = (await branchCollection('inventoryReceipts')).doc();
    final movements = await branchCollection('inventoryMovements');
    // A query cannot run inside a transaction, so the request's other live orders are read first.
    final order = (await orderRef.get()).data();
    if (order == null) failWith('Purchase order not found');
    final requestId = (order['purchaseRequestIds'] as List).first as String;
    final requestRef = await branchDoc('inventoryPurchaseRequests/$requestId');
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
        failWith('Order is ${purchaseOrder['status']}');
      }
      final store = (await transaction.get(storeRef)).data();
      if (store == null) failWith('Store not found');
      if (store['status'] != 'active') failWith('Store is inactive');
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
          failWith('Receiving lines must be lines of the order');
        }
        final accepted = (line['quantityAccepted'] as num? ?? 0).toDouble();
        final rejected = (line['quantityRejected'] as num? ?? 0).toDouble();
        if (accepted < 0 || rejected < 0 || accepted + rejected <= 0) {
          failWith('Each line needs a quantity');
        }
        final got = accepted + rejected;
        // Only accepted units fill the order; rejected ones leave it open for a replacement.
        if (got >
            (orderLine['quantityOrdered']! as num) -
                (orderLine['quantityAccepted']! as num)) {
          failWith('Received quantity exceeds what is still due on the order');
        }
        final rawItem = (await transaction.get(
          await branchDoc('inventoryItems/$itemId'),
        )).data();
        if (rawItem == null) failWith('Item not found');
        final asset = rawItem['tracking'] == 'asset';
        if (asset && got != got.roundToDouble()) {
          failWith('Assets are received in whole units');
        }
        String? batchNumber;
        String? expiryDate;
        Map<String, dynamic>? balance;
        var balanceRef = counterRef;
        if (!asset) {
          final item = await activeStockItem(transaction, itemId, variantId);
          if (item['tracking'] == 'batch') {
            batchNumber = blankToNullText(line['batchNumber']);
            if (batchNumber == null) {
              failWith('${item['name']} needs a batch number');
            }
            expiryDate = blankToNullText(line['expiryDate']);
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
          balanceRef = await branchDoc('inventoryBalances/$balanceId');
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
            condition: blankToNullText(line['condition']),
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
          addStock(
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
        'reference': blankToNullText(data['deliveryRef']),
        'remarks': blankToNullText(data['remarks']),
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
        'lastWrite': writeStamp('inventoryReceipt.create'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(orderRef, {
        'lineItems': orderLines,
        'status': full ? 'fully_received' : 'partially_received',
        'lastWrite': writeStamp('inventoryPurchaseOrder.receive'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // The request is completed once its last live order is fully received.
      if (full &&
          !otherLiveOrders &&
          requestSnapshot.data()?['status'] == 'ordered') {
        transaction.update(requestRef, {
          'status': 'completed',
          'lastWrite': writeStamp('inventoryPurchaseRequest.complete'),
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
