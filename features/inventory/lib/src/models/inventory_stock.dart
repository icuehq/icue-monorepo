import 'package:icue_firebase/icue_firebase.dart';

/// Stock models (Inv-2). Parse and display only; every rule lives in Cloud Functions.

DateTime? _t(Object? value) => value is Timestamp ? value.toDate() : null;
List<Map<String, dynamic>> _rows(Object? currentValue) => [
  for (final value in currentValue is List ? currentValue : const [])
    Map<String, dynamic>.from(value as Map),
];

class InventoryBalance {
  const InventoryBalance({
    required this.id,
    required this.storeId,
    required this.itemId,
    required this.available,
    required this.damaged,
    required this.expired,
    required this.receivedTotal,
    required this.issuedTotal,
    required this.value,
    required this.isBelowReorderLevel,
    this.variantId,
    this.batchNumber,
    this.expiryDate,
  });

  factory InventoryBalance.fromMap(String id, Map<String, dynamic> data) =>
      InventoryBalance(
        id: id,
        storeId: data['storeId'] as String? ?? '',
        itemId: data['itemId'] as String? ?? '',
        variantId: data['variantId'] as String?,
        batchNumber: data['batchNumber'] as String?,
        expiryDate: data['expiryDate'] as String?,
        available: readDouble(data['quantityAvailable']),
        damaged: readDouble(data['quantityDamaged']),
        expired: readDouble(data['quantityExpired']),
        receivedTotal: readDouble(data['totalQuantityReceived']),
        issuedTotal: readDouble(data['totalQuantityIssued']),
        value: readDouble(data['value']),
        isBelowReorderLevel: data['isBelowReorderLevel'] == true,
      );

  final String id;
  final String storeId;
  final String itemId;
  final String? variantId;
  final String? batchNumber;
  final String? expiryDate;
  final double available;
  final double damaged;
  final double expired;
  final double receivedTotal;

  /// Net of returns: what is currently out with recipients.
  final double issuedTotal;
  final double value;
  final bool isBelowReorderLevel;
}

class InventoryMovement {
  const InventoryMovement({
    required this.type,
    required this.quantity,
    required this.bucket,
    required this.referenceType,
    required this.transactionDate,
    this.batchNumber,
    this.createdAt,
  });

  factory InventoryMovement.fromMap(Map<String, dynamic> data) =>
      InventoryMovement(
        type: data['type'] as String? ?? '',
        quantity: readDouble(data['quantity']),
        bucket: data['bucket'] as String? ?? 'available',
        referenceType: data['referenceType'] as String? ?? '',
        transactionDate: data['transactionDate'] as String? ?? '',
        batchNumber: data['batchNumber'] as String?,
        createdAt: _t(data['createdAt']),
      );

  final String type;
  final double quantity;
  final String bucket;
  final String referenceType;
  final String transactionDate;
  final String? batchNumber;
  final DateTime? createdAt;
}

class RequestLine {
  const RequestLine({
    required this.itemId,
    required this.requested,
    required this.approved,
    required this.issued,
    this.variantId,
  });

  factory RequestLine.fromMap(Map<String, dynamic> data) => RequestLine(
    itemId: data['itemId'] as String? ?? '',
    variantId: data['variantId'] as String?,
    requested: readDouble(data['quantityRequested']),
    approved: data['quantityApproved'] == null
        ? null
        : readDouble(data['quantityApproved']),
    issued: readDouble(data['quantityIssued']),
  );

  final String itemId;
  final String? variantId;
  final double requested;
  final double? approved;
  final double issued;
}

class InventoryIssueRequest {
  const InventoryIssueRequest({
    required this.id,
    required this.number,
    required this.storeId,
    required this.campusId,
    required this.purpose,
    required this.status,
    required this.createdBy,
    required this.lineItems,
    this.destination,
    this.approvalComment,
    this.createdAt,
  });

  factory InventoryIssueRequest.fromMap(String id, Map<String, dynamic> data) =>
      InventoryIssueRequest(
        id: id,
        number: data['number'] as String? ?? '',
        storeId: data['storeId'] as String? ?? '',
        campusId: (data['campusId'] as num? ?? 0).toInt(),
        purpose: data['purpose'] as String? ?? '',
        destination: data['destination'] as String?,
        status: data['status'] as String? ?? '',
        createdBy: data['createdBy'] as String? ?? '',
        approvalComment:
            (data['approval'] as Map<String, dynamic>?)?['comment'] as String?,
        lineItems: _rows(data['lineItems']).map(RequestLine.fromMap).toList(),
        createdAt: _t(data['createdAt']),
      );

  final String id;
  final String number;
  final String storeId;
  final int campusId;
  final String purpose;
  final String? destination;

  /// pending | approved | rejected | partially_issued | issued | cancelled | closed
  final String status;
  final String createdBy;
  final String? approvalComment;
  final List<RequestLine> lineItems;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isIssuable => status == 'approved' || status == 'partially_issued';
}

class IssueLine {
  const IssueLine({
    required this.balanceId,
    required this.itemId,
    required this.quantity,
    required this.returned,
    this.variantId,
    this.batchNumber,
  });

  factory IssueLine.fromMap(Map<String, dynamic> data) => IssueLine(
    balanceId: data['balanceId'] as String? ?? '',
    itemId: data['itemId'] as String? ?? '',
    variantId: data['variantId'] as String?,
    batchNumber: data['batchNumber'] as String?,
    quantity: readDouble(data['quantity']),
    returned: readDouble(data['quantityReturned']),
  );

  final String balanceId;
  final String itemId;
  final String? variantId;
  final String? batchNumber;
  final double quantity;
  final double returned;

  double get outstanding => quantity - returned;
}

class InventoryIssue {
  const InventoryIssue({
    required this.id,
    required this.number,
    required this.lineItems,
    required this.acknowledged,
    this.recipientType,
    this.recipientId,
    this.createdAt,
  });

  factory InventoryIssue.fromMap(String id, Map<String, dynamic> data) =>
      InventoryIssue(
        id: id,
        number: data['number'] as String? ?? '',
        lineItems: _rows(data['lineItems']).map(IssueLine.fromMap).toList(),
        acknowledged: data['acknowledgement'] != null,
        recipientType:
            (data['recipient'] as Map<String, dynamic>?)?['type'] as String?,
        recipientId:
            ((data['recipient'] as Map<String, dynamic>?)?['personErpId']
                    as num?)
                ?.toInt(),
        createdAt: _t(data['createdAt']),
      );

  final String id;
  final String number;
  final List<IssueLine> lineItems;
  final bool acknowledged;

  /// staff | student | department
  final String? recipientType;
  final int? recipientId;
  final DateTime? createdAt;
}

class TransferLine {
  const TransferLine({
    required this.itemId,
    required this.dispatched,
    required this.received,
    required this.discrepancy,
    this.variantId,
    this.batchNumber,
  });

  factory TransferLine.fromMap(Map<String, dynamic> data) => TransferLine(
    itemId: data['itemId'] as String? ?? '',
    variantId: data['variantId'] as String?,
    batchNumber: data['batchNumber'] as String?,
    dispatched: readDouble(data['quantityDispatched']),
    received: readDouble(data['quantityReceived']),
    discrepancy: readDouble(data['discrepancy']),
  );

  final String itemId;
  final String? variantId;
  final String? batchNumber;
  final double dispatched;
  final double received;
  final double discrepancy;
}

class InventoryTransfer {
  const InventoryTransfer({
    required this.id,
    required this.number,
    required this.fromStoreId,
    required this.toStoreId,
    required this.fromCampusId,
    required this.toCampusId,
    required this.status,
    required this.requested,
    required this.lineItems,
    this.remarks,
    this.dispatchedDate,
    this.receivedDate,
    this.createdAt,
    this.createdBy = '',
  });

  factory InventoryTransfer.fromMap(String id, Map<String, dynamic> data) {
    final from = data['from'] as Map<String, dynamic>? ?? {};
    final to = data['to'] as Map<String, dynamic>? ?? {};
    return InventoryTransfer(
      id: id,
      number: data['number'] as String? ?? '',
      fromStoreId: from['storeId'] as String? ?? '',
      toStoreId: to['storeId'] as String? ?? '',
      fromCampusId: (from['campusId'] as num? ?? 0).toInt(),
      toCampusId: (to['campusId'] as num? ?? 0).toInt(),
      status: data['status'] as String? ?? '',
      requested: [
        for (final row in _rows(data['requested']))
          (
            itemId: row['itemId'] as String? ?? '',
            variantId: row['variantId'] as String?,
            quantity: readDouble(row['quantity']),
          ),
      ],
      lineItems: _rows(data['lineItems']).map(TransferLine.fromMap).toList(),
      remarks: data['remarks'] as String?,
      dispatchedDate:
          (data['dispatch'] as Map<String, dynamic>?)?['date'] as String?,
      receivedDate:
          (data['receipt'] as Map<String, dynamic>?)?['date'] as String?,
      createdAt: _t(data['createdAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  final String id;
  final String number;
  final String fromStoreId;
  final String toStoreId;
  final int fromCampusId;
  final int toCampusId;

  /// requested | approved | dispatched | partially_received | received | cancelled
  final String status;
  final List<({String itemId, String? variantId, double quantity})> requested;
  final List<TransferLine> lineItems;
  final String? remarks;
  final String? dispatchedDate;
  final String? receivedDate;
  final DateTime? createdAt;
  final String createdBy;

  /// Nothing has left the source store yet.
  bool get preDispatch => status == 'requested' || status == 'approved';

  bool get inTransit =>
      status == 'dispatched' || status == 'partially_received';
}

class InventoryUnavailable {
  const InventoryUnavailable({
    required this.id,
    required this.itemId,
    required this.storeId,
    required this.quantity,
    required this.reason,
    required this.status,
    this.variantId,
    this.batchNumber,
    this.bucket,
    this.remarks,
    this.resolution,
    this.createdAt,
  });

  factory InventoryUnavailable.fromMap(String id, Map<String, dynamic> data) =>
      InventoryUnavailable(
        id: id,
        itemId: data['itemId'] as String? ?? '',
        variantId: data['variantId'] as String?,
        storeId: data['storeId'] as String? ?? '',
        batchNumber: data['batchNumber'] as String?,
        quantity: readDouble(data['quantity']),
        bucket: data['bucket'] as String?,
        reason: data['reason'] as String? ?? '',
        remarks: data['remarks'] as String?,
        status: data['status'] as String? ?? '',
        resolution: data['resolution'] as String?,
        createdAt: _t(data['createdAt']),
      );

  final String id;
  final String itemId;
  final String? variantId;
  final String storeId;
  final String? batchNumber;
  final double quantity;
  final String? bucket;
  final String reason;
  final String? remarks;

  /// open | in_repair | resolved
  final String status;
  final String? resolution;
  final DateTime? createdAt;

  bool get isOpen => status != 'resolved';
}
