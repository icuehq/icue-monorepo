import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';

/// Helpers shared by the stock write classes: failures, item and balance lookups, FEFO
/// allocation, balance changes and ledger rows.
mixin StockSupport {
  Never failWith(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );

  String? blankToNullText(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// `collection/id[/sub/id]` under the school.
  Future<DocumentReference<Map<String, dynamic>>> branchDoc(String path) async {
    final segments = path.split('/');
    return (await branchCollection(segments.first))
        .doc(segments.skip(1).join('/'));
  }

  /// Active, stock-tracked item whose variant requirement matches [variantId].
  Future<Map<String, dynamic>> activeStockItem(
    Transaction transaction,
    String itemId,
    String? variantId, {
    bool inactiveOk = false,
  }) async {
    final item = (await transaction.get(
      await branchDoc('inventoryItems/$itemId'),
    )).data();
    if (item == null) failWith('Item not found');
    final name = item['name'];
    if (!inactiveOk && item['status'] != 'active') {
      failWith('$name is inactive');
    }
    if (item['tracking'] == 'asset') {
      failWith('$name is an individual asset; assets are managed separately');
    }
    final hasVariants =
        ((item['variantAttrs'] as List?) ?? const []).isNotEmpty;
    if (hasVariants != (variantId != null)) {
      failWith(hasVariants ? '$name needs a variant' : '$name has no variants');
    }
    if (variantId != null) {
      final variant = (await transaction.get(
        await branchDoc('inventoryItems/$itemId/variants/$variantId'),
      )).data();
      if (variant == null) failWith('Variant not found');
      if (!inactiveOk && variant['status'] != 'active') {
        failWith('Variant is inactive');
      }
    }
    return item;
  }

  String get currentFinancialYear =>
      DateTime.now().toIndianTime().financialYear;

  /// Issuable (non-expired) stock of an item in a store. Issuance re-checks it, so an
  /// approver who may not read balances (`inventory.stock.view`) is not blocked here.
  Future<double> availableStock(
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

  /// Queries cannot run inside a transaction: find each line's balances first,
  /// then re-read them in the transaction so the quantities are current.
  Future<Map<String, List<DocumentReference<Map<String, dynamic>>>>>
  findCandidateBalances(
    String storeId,
    List<Map<String, dynamic>> lines,
  ) async {
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
  Future<List<IssuePick>> allocateStock(
    Transaction transaction,
    List<DocumentReference<Map<String, dynamic>>> references,
    double quantity,
    Object? itemName,
  ) async {
    final today = todayIST();
    final available = <IssueBalance>[];
    for (final reference in references) {
      final balance = (await transaction.get(reference)).data();
      final expiry = readDayOrNull(balance?['expiryDate']);
      if (balance != null &&
          (balance['quantityAvailable'] as num) > 0 &&
          (expiry == null || expiry.compareTo(today) >= 0)) {
        available.add(IssueBalance(reference, balance, expiry));
      }
    }
    // First expiry first; stock without an expiry last.
    available.sort(
      (left, right) =>
          (left.expiry ?? '9999-12-31').compareTo(right.expiry ?? '9999-12-31'),
    );
    var left = quantity;
    final picks = <IssuePick>[];
    for (final balance in available) {
      if (left <= 0) break;
      final take = left < balance.quantityAvailable
          ? left
          : balance.quantityAvailable;
      picks.add(IssuePick(balance, take));
      left -= take;
    }
    if (left > 0) failWith('Insufficient stock of $itemName');
    return picks;
  }

  /// Takes a pick out of its balance and appends the ledger row ([ledger] holds the shared fields).
  /// A negative pick puts stock back (adjustments).
  void takeStock(
    Transaction transaction,
    CollectionReference<Map<String, dynamic>> movements,
    IssuePick pick, {
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
  void addStock(
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
    setBalance(
      transaction,
      reference,
      balance,
      storeId: storeId,
      itemId: itemId,
      variantId: variantId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      quantity: quantity,
      unitCost: unitCost,
      reorderLevel: reorderLevel,
      manufacturingDate: manufacturingDate,
    );
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

  /// Adds [quantity] to a balance (created if missing) at the weighted-average cost.
  void setBalance(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic>? balance, {
    required String storeId,
    required String itemId,
    required String? variantId,
    required String? batchNumber,
    required String? expiryDate,
    required double quantity,
    required double unitCost,
    required double? reorderLevel,
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
      failWith('Batch $batchNumber already exists with expiry $storedExpiry');
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
  }

  static const bucketFields = {
    'damaged': 'quantityDamaged',
    'expired': 'quantityExpired',
  };

  /// A ledger row for one bucket of a balance.
  void writeMovement(
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
}

class IssueBalance {
  IssueBalance(this.reference, this.data, this.expiry);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;
  final String? expiry;

  double get quantityAvailable => (data['quantityAvailable'] as num).toDouble();
}

class IssuePick {
  IssuePick(this.balance, this.quantity);

  final IssueBalance balance;
  final double quantity;
}
