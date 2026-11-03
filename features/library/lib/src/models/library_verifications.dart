String verificationStatusLabel(String value) => switch (value) {
  'counting' => 'Counting',
  'submitted' => 'To review',
  'approved' => 'Approved',
  _ => value,
};

/// A library stock verification session (FRS 11.16). Copy IDs are accession numbers.
class LibraryVerification {
  const LibraryVerification({
    required this.id,
    required this.number,
    required this.libraryName,
    required this.status,
    required this.expected,
    required this.onLoanCopyIds,
    required this.scanned,
    required this.missing,
    required this.unexpected,
    required this.investigate,
    this.shelf,
    this.verifiedDate,
  });

  factory LibraryVerification.fromMap(String id, Map<String, dynamic> data) {
    List<String> ids(String currentValue) => [
      for (final value in (data[currentValue] as List? ?? const []))
        value as String,
    ];
    return LibraryVerification(
      id: id,
      number: data['number'] as String? ?? id,
      libraryName: data['libraryName'] as String? ?? '',
      status: data['status'] as String? ?? 'counting',
      expected: ids('expected'),
      onLoanCopyIds: ids('onLoanCopyIds'),
      scanned: ids('scanned'),
      missing: ids('missing'),
      unexpected: ids('unexpected'),
      investigate: ids('investigate'),
      shelf: data['shelf'] as String?,
      verifiedDate: data['verifiedDate'] as String?,
    );
  }

  final String id;
  final String number;
  final String libraryName;
  final String status;
  final List<String> expected;
  final List<String> onLoanCopyIds;
  final List<String> scanned;
  final List<String> missing;
  final List<String> unexpected;
  final List<String> investigate;
  final String? shelf;
  final String? verifiedDate;

  bool get isCounting => status == 'counting';
  bool get isSubmitted => status == 'submitted';

  /// Expected copies not scanned yet (final `missing` once submitted).
  List<String> get notYetScanned {
    final values = scanned.toSet();
    return [
      for (final value in expected)
        if (!values.contains(value)) value,
    ];
  }
}
