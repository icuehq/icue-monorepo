const copyConditions = ['good', 'fair', 'poor'];

/// Statuses a librarian may set by hand (the callable rejects the rest).
const copyManualStatuses = [
  'available',
  'under_maintenance',
  'damaged',
  'lost',
  'withdrawn',
];

String copyStatusLabel(String s) => switch (s) {
  'available' => 'Available',
  'issued' => 'Issued',
  'reserved' => 'Reserved',
  'under_maintenance' => 'Under maintenance',
  'damaged' => 'Damaged',
  'lost' => 'Lost',
  'withdrawn' => 'Withdrawn',
  'in_transit' => 'In transit',
  _ => s,
};

/// One physical book. The document ID is the accession number.
class LibCopy {
  const LibCopy({
    required this.id,
    required this.accessionNo,
    required this.catalogueId,
    required this.libraryId,
    required this.campusId,
    required this.condition,
    required this.status,
    required this.price,
    this.shelf,
    this.barcode,
    this.rfidTag,
    this.source,
    this.vendorOrDonor,
    this.acquiredOn,
    this.remarks,
  });

  factory LibCopy.fromMap(String id, Map<String, dynamic> m) => LibCopy(
    id: id,
    accessionNo: m['accessionNo'] as String? ?? id,
    catalogueId: m['catalogueId'] as String? ?? '',
    libraryId: m['libraryId'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    shelf: m['shelf'] as String?,
    barcode: m['barcode'] as String?,
    rfidTag: m['rfidTag'] as String?,
    condition: m['condition'] as String? ?? 'good',
    status: m['status'] as String? ?? 'available',
    price: (m['price'] as num? ?? 0).toDouble(),
    source: m['source'] as String?,
    vendorOrDonor: m['vendorOrDonor'] as String?,
    acquiredOn: m['acquiredOn'] as String?,
    remarks: m['remarks'] as String?,
  );

  final String id;
  final String accessionNo;
  final String catalogueId;
  final String libraryId;
  final int campusId;
  final String? shelf;
  final String? barcode;
  final String? rfidTag;
  final String condition;
  final String status;
  final double price;
  final String? source;
  final String? vendorOrDonor;
  final String? acquiredOn;
  final String? remarks;

  /// Lost and withdrawn copies are final; issued/reserved/in-transit belong to circulation.
  bool get canChangeStatus =>
      copyManualStatuses.contains(status) &&
      status != 'lost' &&
      status != 'withdrawn';
}

class LibAcquisition {
  const LibAcquisition({
    required this.id,
    required this.number,
    required this.type,
    required this.catalogueId,
    required this.libraryId,
    required this.qty,
    required this.price,
    this.date,
    this.vendorOrDonor,
    this.reference,
  });

  factory LibAcquisition.fromMap(String id, Map<String, dynamic> m) =>
      LibAcquisition(
        id: id,
        number: m['number'] as String? ?? '',
        type: m['type'] as String? ?? 'purchase',
        catalogueId: m['catalogueId'] as String? ?? '',
        libraryId: m['libraryId'] as String? ?? '',
        qty: (m['qty'] as num? ?? 0).toInt(),
        price: (m['price'] as num? ?? 0).toDouble(),
        date: m['date'] as String?,
        vendorOrDonor: m['vendorOrDonor'] as String?,
        reference: m['reference'] as String?,
      );

  final String id;
  final String number;
  final String type;
  final String catalogueId;
  final String libraryId;
  final int qty;
  final double price;
  final String? date;
  final String? vendorOrDonor;
  final String? reference;
}
