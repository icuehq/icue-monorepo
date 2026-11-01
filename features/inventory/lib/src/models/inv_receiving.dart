// Goods receiving notes and vendor invoices (Inv-5). Parse and display only; rules live in Cloud Functions.

double _n(Object? v) => (v as num? ?? 0).toDouble();

class GrnLine {
  const GrnLine({
    required this.itemId,
    required this.accepted,
    required this.rejected,
    this.variantId,
    this.condition,
    this.batchNo,
  });

  factory GrnLine.fromMap(Map<String, dynamic> m) => GrnLine(
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    accepted: _n(m['qtyAccepted']),
    rejected: _n(m['qtyRejected']),
    condition: m['condition'] as String?,
    batchNo: m['batchNo'] as String?,
  );

  final String itemId;
  final String? variantId;
  final double accepted;
  final double rejected;
  final String? condition;
  final String? batchNo;
}

/// One delivery against a purchase order (`invReceipts` with `source: purchase_order`).
class InvGrn {
  const InvGrn({
    required this.id,
    required this.number,
    required this.date,
    required this.result,
    required this.lines,
    this.reference,
    this.remarks,
  });

  factory InvGrn.fromMap(String id, Map<String, dynamic> m) => InvGrn(
    id: id,
    number: m['number'] as String? ?? '',
    date: m['txnDate'] as String? ?? '',
    result: (m['inspection'] as Map?)?['result'] as String? ?? 'accepted',
    reference: m['reference'] as String?,
    remarks: m['remarks'] as String?,
    lines: [
      for (final l in m['lines'] is List ? m['lines'] as List : [])
        GrnLine.fromMap(Map<String, dynamic>.from(l as Map)),
    ],
  );

  final String id;
  final String number;
  final String date;

  /// `accepted`, `partial` or `rejected`.
  final String result;
  final String? reference;
  final String? remarks;
  final List<GrnLine> lines;
}

/// A vendor invoice record. Payment fields mirror what Finance reports; nothing is paid from here.
class InvInvoice {
  const InvInvoice({
    required this.id,
    required this.invoiceNo,
    required this.vendorId,
    required this.poId,
    required this.poNumber,
    required this.invoiceDate,
    required this.paymentStatus,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.paidAmount,
    required this.outstanding,
    required this.receiptIds,
    this.dueDate,
    this.remarks,
    this.paymentRef,
  });

  factory InvInvoice.fromMap(String id, Map<String, dynamic> m) => InvInvoice(
    id: id,
    invoiceNo: m['invoiceNo'] as String? ?? '',
    vendorId: m['vendorId'] as String? ?? '',
    poId: m['poId'] as String? ?? '',
    poNumber: m['poNumber'] as String? ?? '',
    invoiceDate: m['invoiceDate'] as String? ?? '',
    dueDate: m['dueDate'] as String?,
    paymentStatus: m['paymentStatus'] as String? ?? 'unpaid',
    subtotal: _n(m['subtotal']),
    tax: _n(m['tax']),
    discount: _n(m['discount']),
    total: _n(m['total']),
    paidAmount: _n(m['paidAmount']),
    outstanding: _n(m['outstanding']),
    receiptIds: [
      for (final r in m['receiptIds'] is List ? m['receiptIds'] as List : [])
        r as String,
    ],
    remarks: m['remarks'] as String?,
    paymentRef: (m['payment'] as Map?)?['reference'] as String?,
  );

  final String id;
  final String invoiceNo;
  final String vendorId;
  final String poId;
  final String poNumber;
  final String invoiceDate;
  final String? dueDate;
  final String paymentStatus;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final double paidAmount;
  final double outstanding;
  final List<String> receiptIds;
  final String? remarks;
  final String? paymentRef;

  bool get isCancelled => paymentStatus == 'cancelled';
  bool get isUnpaid => paymentStatus == 'unpaid';

  /// Stored status, or `overdue` for an unsettled invoice past [today] (`yyyy-mm-dd`) its due date.
  String statusOn(String today) =>
      (paymentStatus == 'unpaid' || paymentStatus == 'partially_paid') &&
          dueDate != null &&
          dueDate!.compareTo(today) < 0
      ? 'overdue'
      : paymentStatus;
}
