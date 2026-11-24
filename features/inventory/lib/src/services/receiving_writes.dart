import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/services/stock_support.dart';

/// Receive Stock.
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
