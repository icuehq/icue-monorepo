import 'package:icue_firebase/icue_firebase.dart';

/// Stock models (Inv-2). Parse and display only; every rule lives in Cloud Functions.

double _n(Object? v) => (v as num? ?? 0).toDouble();
DateTime? _t(Object? v) => v is Timestamp ? v.toDate() : null;
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in v is List ? v : const []) Map<String, dynamic>.from(r as Map),
];

/// `12` -> `12`, `12.5` -> `12.5`.
String fmtQty(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class InvBalance {
  const InvBalance({
    required this.id,
    required this.storeId,
    required this.itemId,
    required this.available,
    required this.damaged,
    required this.expired,
    required this.receivedTotal,
    required this.issuedTotal,
    required this.value,
    required this.belowReorder,
    this.variantId,
    this.batchNo,
    this.expiryDate,
  });

  factory InvBalance.fromMap(String id, Map<String, dynamic> m) => InvBalance(
    id: id,
    storeId: m['storeId'] as String? ?? '',
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    batchNo: m['batchNo'] as String?,
    expiryDate: m['expiryDate'] as String?,
    available: _n(m['qtyAvailable']),
    damaged: _n(m['qtyDamaged']),
    expired: _n(m['qtyExpired']),
    receivedTotal: _n(m['qtyReceivedTotal']),
    issuedTotal: _n(m['qtyIssuedTotal']),
    value: _n(m['value']),
    belowReorder: m['belowReorder'] == true,
  );

  final String id;
  final String storeId;
  final String itemId;
  final String? variantId;
  final String? batchNo;
  final String? expiryDate;
  final double available;
  final double damaged;
  final double expired;
  final double receivedTotal;

  /// Net of returns: what is currently out with recipients.
  final double issuedTotal;
  final double value;
  final bool belowReorder;
}

class InvMovement {
  const InvMovement({
    required this.type,
    required this.qty,
    required this.bucket,
    required this.refType,
    required this.txnDate,
    this.batchNo,
    this.at,
  });

  factory InvMovement.fromMap(Map<String, dynamic> m) => InvMovement(
    type: m['type'] as String? ?? '',
    qty: _n(m['qty']),
    bucket: m['bucket'] as String? ?? 'available',
    refType: m['refType'] as String? ?? '',
    txnDate: m['txnDate'] as String? ?? '',
    batchNo: m['batchNo'] as String?,
    at: _t(m['createdAt']),
  );

  final String type;
  final double qty;
  final String bucket;
  final String refType;
  final String txnDate;
  final String? batchNo;
  final DateTime? at;
}

class RequestLine {
  const RequestLine({
    required this.itemId,
    required this.requested,
    required this.approved,
    required this.issued,
    this.variantId,
  });

  factory RequestLine.fromMap(Map<String, dynamic> m) => RequestLine(
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    requested: _n(m['qtyRequested']),
    approved: m['qtyApproved'] == null ? null : _n(m['qtyApproved']),
    issued: _n(m['qtyIssued']),
  );

  final String itemId;
  final String? variantId;
  final double requested;
  final double? approved;
  final double issued;
}

class InvIssueRequest {
  const InvIssueRequest({
    required this.id,
    required this.number,
    required this.storeId,
    required this.campusId,
    required this.purpose,
    required this.status,
    required this.createdBy,
    required this.lines,
    this.destination,
    this.approvalComment,
    this.createdAt,
  });

  factory InvIssueRequest.fromMap(String id, Map<String, dynamic> m) =>
      InvIssueRequest(
        id: id,
        number: m['number'] as String? ?? '',
        storeId: m['storeId'] as String? ?? '',
        campusId: (m['campusId'] as num? ?? 0).toInt(),
        purpose: m['purpose'] as String? ?? '',
        destination: m['destination'] as String?,
        status: m['status'] as String? ?? '',
        createdBy: m['createdBy'] as String? ?? '',
        approvalComment:
            (m['approval'] as Map<String, dynamic>?)?['comment'] as String?,
        lines: _rows(m['lines']).map(RequestLine.fromMap).toList(),
        createdAt: _t(m['createdAt']),
      );

  final String id;
  final String number;
  final String storeId;
  final int campusId;
  final String purpose;
  final String? destination;

  /// pending | approved | rejected | partially_issued | issued
  final String status;
  final String createdBy;
  final String? approvalComment;
  final List<RequestLine> lines;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isIssuable => status == 'approved' || status == 'partially_issued';
}

class IssueLine {
  const IssueLine({
    required this.balanceId,
    required this.itemId,
    required this.qty,
    required this.returned,
    this.variantId,
    this.batchNo,
  });

  factory IssueLine.fromMap(Map<String, dynamic> m) => IssueLine(
    balanceId: m['balanceId'] as String? ?? '',
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    batchNo: m['batchNo'] as String?,
    qty: _n(m['qty']),
    returned: _n(m['qtyReturned']),
  );

  final String balanceId;
  final String itemId;
  final String? variantId;
  final String? batchNo;
  final double qty;
  final double returned;

  double get outstanding => qty - returned;
}

class InvIssue {
  const InvIssue({
    required this.id,
    required this.number,
    required this.lines,
    required this.acknowledged,
    this.createdAt,
  });

  factory InvIssue.fromMap(String id, Map<String, dynamic> m) => InvIssue(
    id: id,
    number: m['number'] as String? ?? '',
    lines: _rows(m['lines']).map(IssueLine.fromMap).toList(),
    acknowledged: m['ack'] != null,
    createdAt: _t(m['createdAt']),
  );

  final String id;
  final String number;
  final List<IssueLine> lines;
  final bool acknowledged;
  final DateTime? createdAt;
}

class TransferLine {
  const TransferLine({
    required this.itemId,
    required this.dispatched,
    required this.received,
    required this.discrepancy,
    this.variantId,
    this.batchNo,
  });

  factory TransferLine.fromMap(Map<String, dynamic> m) => TransferLine(
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    batchNo: m['batchNo'] as String?,
    dispatched: _n(m['qtyDispatched']),
    received: _n(m['qtyReceived']),
    discrepancy: _n(m['discrepancy']),
  );

  final String itemId;
  final String? variantId;
  final String? batchNo;
  final double dispatched;
  final double received;
  final double discrepancy;
}

class InvTransfer {
  const InvTransfer({
    required this.id,
    required this.number,
    required this.fromStoreId,
    required this.toStoreId,
    required this.fromCampusId,
    required this.toCampusId,
    required this.status,
    required this.requested,
    required this.lines,
    this.createdAt,
  });

  factory InvTransfer.fromMap(String id, Map<String, dynamic> m) {
    final from = m['from'] as Map<String, dynamic>? ?? {};
    final to = m['to'] as Map<String, dynamic>? ?? {};
    return InvTransfer(
      id: id,
      number: m['number'] as String? ?? '',
      fromStoreId: from['storeId'] as String? ?? '',
      toStoreId: to['storeId'] as String? ?? '',
      fromCampusId: (from['campusId'] as num? ?? 0).toInt(),
      toCampusId: (to['campusId'] as num? ?? 0).toInt(),
      status: m['status'] as String? ?? '',
      requested: [
        for (final r in _rows(m['requested']))
          (
            itemId: r['itemId'] as String? ?? '',
            variantId: r['variantId'] as String?,
            qty: _n(r['qty']),
          ),
      ],
      lines: _rows(m['lines']).map(TransferLine.fromMap).toList(),
      createdAt: _t(m['createdAt']),
    );
  }

  final String id;
  final String number;
  final String fromStoreId;
  final String toStoreId;
  final int fromCampusId;
  final int toCampusId;

  /// requested | dispatched | partially_received | received
  final String status;
  final List<({String itemId, String? variantId, double qty})> requested;
  final List<TransferLine> lines;
  final DateTime? createdAt;

  bool get inTransit =>
      status == 'dispatched' || status == 'partially_received';
}

class InvUnavailable {
  const InvUnavailable({
    required this.id,
    required this.itemId,
    required this.storeId,
    required this.qty,
    required this.reason,
    required this.status,
    this.variantId,
    this.batchNo,
    this.bucket,
    this.note,
    this.resolution,
    this.createdAt,
  });

  factory InvUnavailable.fromMap(String id, Map<String, dynamic> m) =>
      InvUnavailable(
        id: id,
        itemId: m['itemId'] as String? ?? '',
        variantId: m['variantId'] as String?,
        storeId: m['storeId'] as String? ?? '',
        batchNo: m['batchNo'] as String?,
        qty: _n(m['qty']),
        bucket: m['bucket'] as String?,
        reason: m['reason'] as String? ?? '',
        note: m['note'] as String?,
        status: m['status'] as String? ?? '',
        resolution: m['resolution'] as String?,
        createdAt: _t(m['createdAt']),
      );

  final String id;
  final String itemId;
  final String? variantId;
  final String storeId;
  final String? batchNo;
  final double qty;
  final String? bucket;
  final String reason;
  final String? note;

  /// open | in_repair | resolved
  final String status;
  final String? resolution;
  final DateTime? createdAt;

  bool get isOpen => status != 'resolved';
}
