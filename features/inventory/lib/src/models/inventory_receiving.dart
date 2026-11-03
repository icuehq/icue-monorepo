import 'package:icue_firebase/icue_firebase.dart' show readDouble;

// Goods receiving notes and vendor invoices (Inv-5). Parse and display only; rules live in Cloud Functions.

class GoodsReceiptLine {
  const GoodsReceiptLine({
    required this.itemId,
    required this.accepted,
    required this.rejected,
    this.variantId,
    this.condition,
    this.batchNumber,
  });

  factory GoodsReceiptLine.fromMap(Map<String, dynamic> data) =>
      GoodsReceiptLine(
        itemId: data['itemId'] as String? ?? '',
        variantId: data['variantId'] as String?,
        accepted: readDouble(data['quantityAccepted']),
        rejected: readDouble(data['quantityRejected']),
        condition: data['condition'] as String?,
        batchNumber: data['batchNumber'] as String?,
      );

  final String itemId;
  final String? variantId;
  final double accepted;
  final double rejected;
  final String? condition;
  final String? batchNumber;
}

/// One delivery against a purchase order (`inventoryReceipts` with `source: purchase_order`).
class InventoryGoodsReceipt {
  const InventoryGoodsReceipt({
    required this.id,
    required this.number,
    required this.date,
    required this.result,
    required this.lineItems,
    this.reference,
    this.remarks,
  });

  factory InventoryGoodsReceipt.fromMap(String id, Map<String, dynamic> data) =>
      InventoryGoodsReceipt(
        id: id,
        number: data['number'] as String? ?? '',
        date: data['transactionDate'] as String? ?? '',
        result:
            (data['inspection'] as Map?)?['result'] as String? ?? 'accepted',
        reference: data['reference'] as String?,
        remarks: data['remarks'] as String?,
        lineItems: [
          for (final value
              in data['lineItems'] is List ? data['lineItems'] as List : [])
            GoodsReceiptLine.fromMap(Map<String, dynamic>.from(value as Map)),
        ],
      );

  final String id;
  final String number;
  final String date;

  /// `accepted`, `partial` or `rejected`.
  final String result;
  final String? reference;
  final String? remarks;
  final List<GoodsReceiptLine> lineItems;
}

/// A vendor invoice record. Payment fields mirror what Finance reports; nothing is paid from here.
class InventoryInvoice {
  const InventoryInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.vendorId,
    required this.purchaseOrderId,
    required this.purchaseOrderNumber,
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

  factory InventoryInvoice.fromMap(String id, Map<String, dynamic> data) =>
      InventoryInvoice(
        id: id,
        invoiceNumber: data['invoiceNumber'] as String? ?? '',
        vendorId: data['vendorId'] as String? ?? '',
        purchaseOrderId: data['purchaseOrderId'] as String? ?? '',
        purchaseOrderNumber: data['purchaseOrderNumber'] as String? ?? '',
        invoiceDate: data['invoiceDate'] as String? ?? '',
        dueDate: data['dueDate'] as String?,
        paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
        subtotal: readDouble(data['subtotal']),
        tax: readDouble(data['tax']),
        discount: readDouble(data['discount']),
        total: readDouble(data['total']),
        paidAmount: readDouble(data['paidAmount']),
        outstanding: readDouble(data['outstanding']),
        receiptIds: [
          for (final value
              in data['receiptIds'] is List ? data['receiptIds'] as List : [])
            value as String,
        ],
        remarks: data['remarks'] as String?,
        paymentRef: (data['payment'] as Map?)?['reference'] as String?,
      );

  final String id;
  final String invoiceNumber;
  final String vendorId;
  final String purchaseOrderId;
  final String purchaseOrderNumber;
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
