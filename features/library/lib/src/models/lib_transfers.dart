String transferStatusLabel(String s) => switch (s) {
  'requested' => 'Requested',
  'approved' => 'Approved',
  'dispatched' => 'In transit',
  'partially_received' => 'Partly received',
  'received' => 'Received',
  _ => s,
};

/// One copy on a transfer; [received] flips when the destination confirms it.
class LibTransferLine {
  const LibTransferLine({
    required this.copyId,
    required this.accessionNo,
    required this.received,
    this.condition,
  });

  factory LibTransferLine.fromMap(Map<String, dynamic> m) => LibTransferLine(
    copyId: m['copyId'] as String? ?? '',
    accessionNo: m['accessionNo'] as String? ?? '',
    received: m['received'] as bool? ?? false,
    condition: m['condition'] as String?,
  );

  final String copyId;
  final String accessionNo;
  final bool received;
  final String? condition;
}

/// A transfer of copies between two libraries of the school (FRS 11.15).
class LibTransfer {
  const LibTransfer({
    required this.id,
    required this.number,
    required this.fromLibraryId,
    required this.toLibraryId,
    required this.campusId,
    required this.toCampusId,
    required this.status,
    required this.lines,
    this.requestedOn,
    this.dispatchedOn,
    this.receivedOn,
    this.remarks,
  });

  factory LibTransfer.fromMap(String id, Map<String, dynamic> m) => LibTransfer(
    id: id,
    number: m['number'] as String? ?? id,
    fromLibraryId: m['fromLibraryId'] as String? ?? '',
    toLibraryId: m['toLibraryId'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    toCampusId: (m['toCampusId'] as num? ?? 0).toInt(),
    status: m['status'] as String? ?? 'requested',
    lines: [
      for (final l in (m['lines'] as List? ?? const []))
        LibTransferLine.fromMap(Map<String, dynamic>.from(l as Map)),
    ],
    requestedOn: m['requestedOn'] as String?,
    dispatchedOn: m['dispatchedOn'] as String?,
    receivedOn: m['receivedOn'] as String?,
    remarks: m['remarks'] as String?,
  );

  final String id;
  final String number;
  final String fromLibraryId;
  final String toLibraryId;
  final int campusId;
  final int toCampusId;
  final String status;
  final List<LibTransferLine> lines;
  final String? requestedOn;
  final String? dispatchedOn;
  final String? receivedOn;
  final String? remarks;

  List<LibTransferLine> get pending => [
    for (final l in lines)
      if (!l.received) l,
  ];
}
