import 'package:icue_firebase/icue_firebase.dart' show readDouble;

// Quotations and purchase orders (Inv-4). Parse and display only; rules live in Cloud Functions.

/// A quotation line (`quantity`) or a purchase-order line (`quantityOrdered`).
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    this.variantId,
    this.quantityReceived = 0,
    this.quantityAccepted = 0,
    this.quantityRejected = 0,
  });

  factory OrderLine.fromMap(Map<String, dynamic> data) => OrderLine(
    itemId: data['itemId'] as String? ?? '',
    variantId: data['variantId'] as String?,
    quantity: readDouble(data['quantity'] ?? data['quantityOrdered']),
    unitPrice: readDouble(data['unitPrice']),
    quantityReceived: readDouble(data['quantityReceived']),
    quantityAccepted: readDouble(data['quantityAccepted']),
    quantityRejected: readDouble(data['quantityRejected']),
  );

  final String itemId;
  final String? variantId;
  final double quantity;
  final double unitPrice;
  final double quantityReceived;
  final double quantityAccepted;
  final double quantityRejected;

  /// Still to be delivered or rejected on a purchase order line.
  double get due => quantity - quantityAccepted;
}

List<OrderLine> _lines(Object? currentValue) => [
  for (final value in currentValue is List ? currentValue : [])
    OrderLine.fromMap(Map<String, dynamic>.from(value as Map)),
];

/// Shared money block of quotations and purchase orders.
abstract class _Priced {
  const _Priced({
    required this.id,
    required this.number,
    required this.vendorId,
    required this.status,
    required this.lineItems,
    required this.discount,
    required this.tax,
    required this.delivery,
    required this.subtotal,
    required this.total,
    this.remarks,
  });

  final String id;
  final String number;
  final String vendorId;
  final String status;
  final List<OrderLine> lineItems;
  final double discount;
  final double tax;
  final double delivery;
  final double subtotal;
  final double total;
  final String? remarks;
}

class InventoryQuotation extends _Priced {
  const InventoryQuotation({
    required super.id,
    required super.number,
    required super.vendorId,
    required super.status,
    required super.lineItems,
    required super.discount,
    required super.tax,
    required super.delivery,
    required super.subtotal,
    required super.total,
    required this.purchaseRequestId,
    required this.validUntil,
    required this.quotationDate,
    required this.selected,
    super.remarks,
    this.vendorRef,
    this.deliveryDays,
    this.selectionReason,
  });

  factory InventoryQuotation.fromMap(String id, Map<String, dynamic> data) =>
      InventoryQuotation(
        id: id,
        number: data['number'] as String? ?? '',
        vendorId: data['vendorId'] as String? ?? '',
        status: data['status'] as String? ?? 'draft',
        lineItems: _lines(data['lineItems']),
        discount: readDouble(data['discount']),
        tax: readDouble(data['tax']),
        delivery: readDouble(data['delivery']),
        subtotal: readDouble(data['subtotal']),
        total: readDouble(data['total']),
        remarks: data['remarks'] as String?,
        purchaseRequestId: data['purchaseRequestId'] as String? ?? '',
        vendorRef: data['vendorRef'] as String?,
        validUntil: data['validUntil'] as String? ?? '',
        quotationDate: data['quotationDate'] as String? ?? '',
        deliveryDays: (data['deliveryDays'] as num?)?.toInt(),
        selected: data['selected'] == true,
        selectionReason: data['selectionReason'] as String?,
      );

  final String purchaseRequestId;
  final String? vendorRef;
  final String validUntil;
  final String quotationDate;
  final int? deliveryDays;
  final bool selected;
  final String? selectionReason;

  bool get isDraft => status == 'draft';
}

class InventoryPurchaseOrder extends _Priced {
  const InventoryPurchaseOrder({
    required super.id,
    required super.number,
    required super.vendorId,
    required super.status,
    required super.lineItems,
    required super.discount,
    required super.tax,
    required super.delivery,
    required super.subtotal,
    required super.total,
    required this.purchaseRequestId,
    required this.campusId,
    required this.deliveryCampusId,
    required this.purchaseOrderDate,
    required this.expectedDate,
    required this.revision,
    super.remarks,
    this.quotationId,
    this.terms,
    this.ackRef,
  });

  factory InventoryPurchaseOrder.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => InventoryPurchaseOrder(
    id: id,
    number: data['number'] as String? ?? '',
    vendorId: data['vendorId'] as String? ?? '',
    status: data['status'] as String? ?? 'draft',
    lineItems: _lines(data['lineItems']),
    discount: readDouble(data['discount']),
    tax: readDouble(data['tax']),
    delivery: readDouble(data['delivery']),
    subtotal: readDouble(data['subtotal']),
    total: readDouble(data['total']),
    remarks: data['remarks'] as String?,
    purchaseRequestId:
        (data['purchaseRequestIds'] is List &&
            (data['purchaseRequestIds'] as List).isNotEmpty)
        ? (data['purchaseRequestIds'] as List).first as String
        : '',
    campusId: (data['campusId'] as num? ?? 0).toInt(),
    deliveryCampusId: (data['deliveryCampusId'] as num? ?? 0).toInt(),
    quotationId: data['quotationId'] as String?,
    purchaseOrderDate: data['purchaseOrderDate'] as String? ?? '',
    expectedDate: data['expectedDate'] as String? ?? '',
    terms: data['terms'] as String?,
    revision: (data['revision'] as num? ?? 0).toInt(),
    ackRef: data['acknowledgement'] is Map
        ? (data['acknowledgement'] as Map)['vendorRef'] as String?
        : null,
  );

  final String purchaseRequestId;
  final int campusId;
  final int deliveryCampusId;
  final String? quotationId;
  final String purchaseOrderDate;
  final String expectedDate;
  final String? terms;
  final int revision;
  final String? ackRef;

  bool get isDraft => status == 'draft';
  bool get isIssued => status == 'issued';

  /// Header and price changes after issue (recorded as a revision).
  bool get canRevise => isIssued || status == 'acknowledged';
  bool get canCancel => isDraft || canRevise;
  bool get canReceive =>
      status == 'issued' ||
      status == 'acknowledged' ||
      status == 'partially_received';
  bool get canClose =>
      canRevise || status == 'partially_received' || status == 'fully_received';
}
