// Quotations and purchase orders (Inv-4). Parse and display only; rules live in Cloud Functions.

double _n(Object? v) => (v as num? ?? 0).toDouble();

/// A quotation line (`qty`) or a purchase-order line (`qtyOrdered`).
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.qty,
    required this.unitPrice,
    this.variantId,
    this.qtyReceived = 0,
    this.qtyAccepted = 0,
    this.qtyRejected = 0,
  });

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    qty: _n(m['qty'] ?? m['qtyOrdered']),
    unitPrice: _n(m['unitPrice']),
    qtyReceived: _n(m['qtyReceived']),
    qtyAccepted: _n(m['qtyAccepted']),
    qtyRejected: _n(m['qtyRejected']),
  );

  final String itemId;
  final String? variantId;
  final double qty;
  final double unitPrice;
  final double qtyReceived;
  final double qtyAccepted;
  final double qtyRejected;

  /// Still to be delivered or rejected on a purchase order line.
  double get due => qty - qtyAccepted - qtyRejected;
}

List<OrderLine> _lines(Object? v) => [
  for (final l in v is List ? v : [])
    OrderLine.fromMap(Map<String, dynamic>.from(l as Map)),
];

/// Shared money block of quotations and purchase orders.
abstract class _Priced {
  const _Priced({
    required this.id,
    required this.number,
    required this.vendorId,
    required this.status,
    required this.lines,
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
  final List<OrderLine> lines;
  final double discount;
  final double tax;
  final double delivery;
  final double subtotal;
  final double total;
  final String? remarks;
}

class InvQuotation extends _Priced {
  const InvQuotation({
    required super.id,
    required super.number,
    required super.vendorId,
    required super.status,
    required super.lines,
    required super.discount,
    required super.tax,
    required super.delivery,
    required super.subtotal,
    required super.total,
    required this.prId,
    required this.validUntil,
    required this.quotationDate,
    required this.selected,
    super.remarks,
    this.vendorRef,
    this.deliveryDays,
    this.selectionReason,
  });

  factory InvQuotation.fromMap(String id, Map<String, dynamic> m) =>
      InvQuotation(
        id: id,
        number: m['number'] as String? ?? '',
        vendorId: m['vendorId'] as String? ?? '',
        status: m['status'] as String? ?? 'draft',
        lines: _lines(m['lines']),
        discount: _n(m['discount']),
        tax: _n(m['tax']),
        delivery: _n(m['delivery']),
        subtotal: _n(m['subtotal']),
        total: _n(m['total']),
        remarks: m['remarks'] as String?,
        prId: m['prId'] as String? ?? '',
        vendorRef: m['vendorRef'] as String?,
        validUntil: m['validUntil'] as String? ?? '',
        quotationDate: m['quotationDate'] as String? ?? '',
        deliveryDays: (m['deliveryDays'] as num?)?.toInt(),
        selected: m['selected'] == true,
        selectionReason: m['selectionReason'] as String?,
      );

  final String prId;
  final String? vendorRef;
  final String validUntil;
  final String quotationDate;
  final int? deliveryDays;
  final bool selected;
  final String? selectionReason;

  bool get isDraft => status == 'draft';
}

class InvPurchaseOrder extends _Priced {
  const InvPurchaseOrder({
    required super.id,
    required super.number,
    required super.vendorId,
    required super.status,
    required super.lines,
    required super.discount,
    required super.tax,
    required super.delivery,
    required super.subtotal,
    required super.total,
    required this.prId,
    required this.campusId,
    required this.deliveryCampusId,
    required this.poDate,
    required this.expectedDate,
    required this.revision,
    super.remarks,
    this.quotationId,
    this.terms,
    this.ackRef,
  });

  factory InvPurchaseOrder.fromMap(String id, Map<String, dynamic> m) =>
      InvPurchaseOrder(
        id: id,
        number: m['number'] as String? ?? '',
        vendorId: m['vendorId'] as String? ?? '',
        status: m['status'] as String? ?? 'draft',
        lines: _lines(m['lines']),
        discount: _n(m['discount']),
        tax: _n(m['tax']),
        delivery: _n(m['delivery']),
        subtotal: _n(m['subtotal']),
        total: _n(m['total']),
        remarks: m['remarks'] as String?,
        prId: (m['prIds'] is List && (m['prIds'] as List).isNotEmpty)
            ? (m['prIds'] as List).first as String
            : '',
        campusId: (m['campusId'] as num? ?? 0).toInt(),
        deliveryCampusId: (m['deliveryCampusId'] as num? ?? 0).toInt(),
        quotationId: m['quotationId'] as String?,
        poDate: m['poDate'] as String? ?? '',
        expectedDate: m['expectedDate'] as String? ?? '',
        terms: m['terms'] as String?,
        revision: (m['revision'] as num? ?? 0).toInt(),
        ackRef: m['ack'] is Map
            ? (m['ack'] as Map)['vendorRef'] as String?
            : null,
      );

  final String prId;
  final int campusId;
  final int deliveryCampusId;
  final String? quotationId;
  final String poDate;
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
