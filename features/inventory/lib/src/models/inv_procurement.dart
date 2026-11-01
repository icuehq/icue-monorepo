import 'package:icue_firebase/icue_firebase.dart';

/// Vendors and purchase requests (Inv-3). Parse and display only; rules live in Cloud Functions.

double _n(Object? v) => (v as num? ?? 0).toDouble();
DateTime? _t(Object? v) => v is Timestamp ? v.toDate() : null;

class InvVendor {
  const InvVendor({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryIds,
    required this.active,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.taxNo,
    this.website,
    this.notes,
  });

  factory InvVendor.fromMap(String id, Map<String, dynamic> m) => InvVendor(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    contactPerson: m['contactPerson'] as String?,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    address: m['address'] as String?,
    taxNo: m['taxNo'] as String?,
    website: m['website'] as String?,
    notes: m['notes'] as String?,
    categoryIds: [
      for (final c in m['categoryIds'] is List ? m['categoryIds'] as List : [])
        c as String,
    ],
    active: m['status'] != 'inactive',
  );

  final String id;
  final String code;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNo;
  final String? website;
  final String? notes;
  final List<String> categoryIds;
  final bool active;
}

class PrLine {
  const PrLine({
    required this.itemId,
    required this.qty,
    required this.estPrice,
    required this.qtyOrdered,
    this.variantId,
  });

  factory PrLine.fromMap(Map<String, dynamic> m) => PrLine(
    itemId: m['itemId'] as String? ?? '',
    variantId: m['variantId'] as String?,
    qty: _n(m['qty']),
    estPrice: _n(m['estPrice']),
    qtyOrdered: _n(m['qtyOrdered']),
  );

  final String itemId;
  final String? variantId;
  final double qty;
  final double estPrice;
  final double qtyOrdered;
}

/// One step of the retained approval history (submit, approve, reject, revise, cancel).
class PrHistory {
  const PrHistory({required this.action, this.comment, this.at});

  factory PrHistory.fromMap(Map<String, dynamic> m) => PrHistory(
    action: m['action'] as String? ?? '',
    comment: m['comment'] as String?,
    at: _t(m['at']),
  );

  final String action;
  final String? comment;
  final DateTime? at;
}

class InvPurchaseRequest {
  const InvPurchaseRequest({
    required this.id,
    required this.number,
    required this.campusId,
    required this.status,
    required this.priority,
    required this.purpose,
    required this.requiredDate,
    required this.total,
    required this.lines,
    required this.history,
    required this.createdBy,
    this.departmentId,
    this.remarks,
    this.createdAt,
  });

  factory InvPurchaseRequest.fromMap(String id, Map<String, dynamic> m) =>
      InvPurchaseRequest(
        id: id,
        number: m['number'] as String? ?? '',
        campusId: (m['campusId'] as num? ?? 0).toInt(),
        departmentId: (m['departmentId'] as num?)?.toInt(),
        status: m['status'] as String? ?? 'draft',
        priority: m['priority'] as String? ?? 'normal',
        purpose: m['purpose'] as String? ?? '',
        remarks: m['remarks'] as String?,
        requiredDate: m['requiredDate'] as String? ?? '',
        total: _n(m['total']),
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: _t(m['createdAt']),
        lines: [
          for (final l in m['lines'] is List ? m['lines'] as List : [])
            PrLine.fromMap(Map<String, dynamic>.from(l as Map)),
        ],
        history: [
          for (final h in m['history'] is List ? m['history'] as List : [])
            PrHistory.fromMap(Map<String, dynamic>.from(h as Map)),
        ],
      );

  final String id;
  final String number;
  final int campusId;
  final int? departmentId;
  final String status;
  final String priority;
  final String purpose;
  final String? remarks;
  final String requiredDate;
  final double total;
  final String createdBy;
  final DateTime? createdAt;
  final List<PrLine> lines;
  final List<PrHistory> history;

  /// The requester may edit and (re)submit these.
  bool get isEditable => status == 'draft' || status == 'revision_requested';
  bool get isPending => status == 'pending';

  /// Quotations and POs may be raised against these.
  bool get isOrderable => status == 'approved' || status == 'partially_ordered';

  /// Cancelled requests stay on record; ordered quantity blocks cancellation.
  bool get isCancellable =>
      const [
        'draft',
        'revision_requested',
        'pending',
        'approved',
      ].contains(status) &&
      lines.every((l) => l.qtyOrdered == 0);
}
