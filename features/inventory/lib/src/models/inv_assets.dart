// Assets, custody and maintenance (Inv-6). Parse and display only; rules live in Cloud Functions.

double _n(Object? v) => (v as num? ?? 0).toDouble();

String _day(Object? v) => v is String ? v : '';

/// Who holds an asset: `staff`, `student` or `department`, by ERP ID.
class AssetCustodian {
  const AssetCustodian(this.type, this.erpId);

  static AssetCustodian? from(Object? m) => m is Map
      ? AssetCustodian(
          m['type'] as String? ?? 'staff',
          (m['erpId'] as num).toInt(),
        )
      : null;

  final String type;
  final int erpId;

  String get label => '$type #$erpId';
}

/// One physical asset (`invAssets`).
class InvAsset {
  const InvAsset({
    required this.id,
    required this.assetId,
    required this.name,
    required this.itemId,
    required this.campusId,
    required this.storeId,
    required this.status,
    required this.condition,
    this.serialNo,
    this.make,
    this.model,
    this.poId,
    this.vendorId,
    this.purchaseDate,
    this.price,
    this.warrantyStart,
    this.warrantyEnd,
    this.location,
    this.assignedTo,
    this.activeAssignmentId,
    this.activeMaintenanceId,
    this.nextServiceDate,
  });

  factory InvAsset.fromMap(String id, Map<String, dynamic> m) => InvAsset(
    id: id,
    assetId: m['assetId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    itemId: m['itemId'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    storeId: m['storeId'] as String? ?? '',
    status: m['status'] as String? ?? 'available',
    condition: m['condition'] as String? ?? 'good',
    serialNo: m['serialNo'] as String?,
    make: m['make'] as String?,
    model: m['model'] as String?,
    poId: m['poId'] as String?,
    vendorId: m['vendorId'] as String?,
    purchaseDate: m['purchaseDate'] as String?,
    price: m['price'] == null ? null : _n(m['price']),
    warrantyStart: (m['warranty'] as Map?)?['start'] as String?,
    warrantyEnd: (m['warranty'] as Map?)?['end'] as String?,
    location: m['location'] as String?,
    assignedTo: AssetCustodian.from(m['assignedTo']),
    activeAssignmentId: m['activeAssignmentId'] as String?,
    activeMaintenanceId: m['activeMaintenanceId'] as String?,
    nextServiceDate: m['nextServiceDate'] as String?,
  );

  final String id;

  /// Human asset ID (`AST/2026-27/000001`); also the barcode / QR value.
  final String assetId;
  final String name;
  final String itemId;
  final int campusId;
  final String storeId;
  final String status;
  final String condition;
  final String? serialNo;
  final String? make;
  final String? model;
  final String? poId;
  final String? vendorId;
  final String? purchaseDate;
  final double? price;
  final String? warrantyStart;
  final String? warrantyEnd;
  final String? location;
  final AssetCustodian? assignedTo;
  final String? activeAssignmentId;
  final String? activeMaintenanceId;
  final String? nextServiceDate;

  static const statuses = [
    'available',
    'assigned',
    'under_maintenance',
    'under_repair',
    'lost',
    'damaged',
    'retired',
    'disposed',
  ];
  static const conditions = ['new', 'good', 'fair', 'poor', 'damaged'];

  bool get isRetired => status == 'retired' || status == 'disposed';
  bool get inMaintenance => activeMaintenanceId != null;
}

/// A custody record (`invAssetAssignments`); a transfer or return closes it and keeps it.
class InvAssignment {
  const InvAssignment({
    required this.id,
    required this.assignee,
    required this.assignedDate,
    this.location,
    this.expectedReturn,
    this.conditionOut,
    this.conditionIn,
    this.returnedDate,
    this.closedAs,
    this.acknowledged = false,
  });

  factory InvAssignment.fromMap(String id, Map<String, dynamic> m) =>
      InvAssignment(
        id: id,
        assignee:
            AssetCustodian.from(m['assignee']) ??
            const AssetCustodian('staff', 0),
        assignedDate: _day(m['assignedDate']),
        location: m['location'] as String?,
        expectedReturn: m['expectedReturn'] as String?,
        conditionOut: m['conditionOut'] as String?,
        conditionIn: m['conditionIn'] as String?,
        returnedDate: m['returnedDate'] as String?,
        closedAs: m['closedAs'] as String?,
        acknowledged: m['ack'] != null,
      );

  final String id;
  final AssetCustodian assignee;
  final String assignedDate;
  final String? location;
  final String? expectedReturn;
  final String? conditionOut;
  final String? conditionIn;
  final String? returnedDate;

  /// `returned`, `transferred` or `lost`; null while active.
  final String? closedAs;
  final bool acknowledged;
}

/// One line of an asset's timeline (`invAssets/{id}/history`).
class AssetEvent {
  const AssetEvent({required this.type, required this.at, this.detail});

  factory AssetEvent.fromMap(Map<String, dynamic> m) => AssetEvent(
    type: m['type'] as String? ?? '',
    at: (m['at'] as dynamic)?.toDate() as DateTime?,
    detail: [
      for (final k in const [
        'number',
        'issue',
        'reason',
        'remarks',
        'condition',
      ])
        if (m[k] != null && '${m[k]}'.isNotEmpty) '${m[k]}',
    ].join(' · '),
  );

  final String type;
  final DateTime? at;
  final String? detail;
}

class PartUsed {
  const PartUsed({required this.itemId, required this.qty});

  final String itemId;
  final double qty;
}

/// A maintenance request (`invMaintenance`).
class InvMaintenance {
  const InvMaintenance({
    required this.id,
    required this.number,
    required this.assetId,
    required this.assetCode,
    required this.assetName,
    required this.issue,
    required this.priority,
    required this.status,
    required this.reportedDate,
    required this.parts,
    this.technician,
    this.repairDetails,
    this.cost,
    this.completedDate,
    this.nextServiceDate,
  });

  factory InvMaintenance.fromMap(String id, Map<String, dynamic> m) =>
      InvMaintenance(
        id: id,
        number: m['number'] as String? ?? '',
        assetId: m['assetId'] as String? ?? '',
        assetCode: m['assetCode'] as String? ?? '',
        assetName: m['assetName'] as String? ?? '',
        issue: m['issue'] as String? ?? '',
        priority: m['priority'] as String? ?? 'medium',
        status: m['status'] as String? ?? 'open',
        reportedDate: _day(m['reportedDate']),
        technician: m['technician'] as String?,
        repairDetails: m['repairDetails'] as String?,
        cost: m['cost'] == null ? null : _n(m['cost']),
        completedDate: m['completedDate'] as String?,
        nextServiceDate: m['nextServiceDate'] as String?,
        parts: [
          for (final p in m['partsUsed'] is List ? m['partsUsed'] as List : [])
            PartUsed(
              itemId: (p as Map)['itemId'] as String? ?? '',
              qty: _n(p['qty']),
            ),
        ],
      );

  final String id;
  final String number;
  final String assetId;
  final String assetCode;
  final String assetName;
  final String issue;
  final String priority;
  final String status;
  final String reportedDate;
  final String? technician;
  final String? repairDetails;
  final double? cost;
  final String? completedDate;
  final String? nextServiceDate;
  final List<PartUsed> parts;

  static const priorities = ['low', 'medium', 'high', 'urgent'];
  static const statuses = [
    'open',
    'assigned',
    'in_progress',
    'waiting_for_parts',
    'completed',
    'cancelled',
  ];

  bool get isLive => status != 'completed' && status != 'cancelled';
}
