import 'package:icue_firebase/icue_firebase.dart';

/// Vendors and purchase requests (Inv-3). Parse and display only; rules live in Cloud Functions.

DateTime? _t(Object? value) => value is Timestamp ? value.toDate() : null;

class InventoryVendor {
  const InventoryVendor({
    required this.id,
    required this.name,
    required this.categoryIds,
    required this.active,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.website,
    this.remarks,
  });

  factory InventoryVendor.fromMap(String id, Map<String, dynamic> data) =>
      InventoryVendor(
        id: id,
        name: data['name'] as String? ?? '',
        contactPerson: data['contactPerson'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        address: data['address'] as String?,
        taxNumber: data['taxNumber'] as String?,
        website: data['website'] as String?,
        remarks: data['remarks'] as String?,
        categoryIds: [
          for (final value
              in data['categoryIds'] is List ? data['categoryIds'] as List : [])
            value as String,
        ],
        active: data['status'] != 'inactive',
      );

  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? website;
  final String? remarks;
  final List<String> categoryIds;
  final bool active;
}

class PurchaseRequestLine {
  const PurchaseRequestLine({
    required this.itemId,
    required this.quantity,
    required this.estimatedPrice,
    required this.quantityOrdered,
    this.variantId,
  });

  factory PurchaseRequestLine.fromMap(Map<String, dynamic> data) =>
      PurchaseRequestLine(
        itemId: data['itemId'] as String? ?? '',
        variantId: data['variantId'] as String?,
        quantity: readDouble(data['quantity']),
        estimatedPrice: readDouble(data['estimatedPrice']),
        quantityOrdered: readDouble(data['quantityOrdered']),
      );

  final String itemId;
  final String? variantId;
  final double quantity;
  final double estimatedPrice;
  final double quantityOrdered;
}

/// One step of the retained approval history (submit, approve, reject, revise, cancel).
class PurchaseRequestHistoryEntry {
  const PurchaseRequestHistoryEntry({
    required this.action,
    this.comment,
    this.performedAt,
  });

  factory PurchaseRequestHistoryEntry.fromMap(Map<String, dynamic> data) =>
      PurchaseRequestHistoryEntry(
        action: data['action'] as String? ?? '',
        comment: data['comment'] as String?,
        performedAt: _t(data['performedAt']),
      );

  final String action;
  final String? comment;
  final DateTime? performedAt;
}

class InventoryPurchaseRequest {
  const InventoryPurchaseRequest({
    required this.id,
    required this.number,
    required this.campusId,
    required this.status,
    required this.priority,
    required this.purpose,
    required this.requiredDate,
    required this.total,
    required this.lineItems,
    required this.history,
    required this.createdBy,
    this.departmentId,
    this.remarks,
    this.createdAt,
  });

  factory InventoryPurchaseRequest.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => InventoryPurchaseRequest(
    id: id,
    number: data['number'] as String? ?? '',
    campusId: (data['campusId'] as num? ?? 0).toInt(),
    departmentId: (data['departmentId'] as num?)?.toInt(),
    status: data['status'] as String? ?? 'draft',
    priority: data['priority'] as String? ?? 'normal',
    purpose: data['purpose'] as String? ?? '',
    remarks: data['remarks'] as String?,
    requiredDate: data['requiredDate'] as String? ?? '',
    total: readDouble(data['total']),
    createdBy: data['createdBy'] as String? ?? '',
    createdAt: _t(data['createdAt']),
    lineItems: [
      for (final value
          in data['lineItems'] is List ? data['lineItems'] as List : [])
        PurchaseRequestLine.fromMap(Map<String, dynamic>.from(value as Map)),
    ],
    history: [
      for (final value
          in data['history'] is List ? data['history'] as List : [])
        PurchaseRequestHistoryEntry.fromMap(
          Map<String, dynamic>.from(value as Map),
        ),
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
  final List<PurchaseRequestLine> lineItems;
  final List<PurchaseRequestHistoryEntry> history;

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
      lineItems.every(
        (purchaseRequestLine) => purchaseRequestLine.quantityOrdered == 0,
      );
}
