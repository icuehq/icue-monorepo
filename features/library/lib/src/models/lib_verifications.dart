String verificationStatusLabel(String s) => switch (s) {
  'counting' => 'Counting',
  'submitted' => 'To review',
  'approved' => 'Approved',
  _ => s,
};

/// A library stock verification session (FRS 11.16). Copy IDs are accession numbers.
class LibVerification {
  const LibVerification({
    required this.id,
    required this.number,
    required this.libraryName,
    required this.status,
    required this.expected,
    required this.onLoan,
    required this.scanned,
    required this.missing,
    required this.unexpected,
    required this.investigate,
    this.shelf,
    this.verifiedOn,
  });

  factory LibVerification.fromMap(String id, Map<String, dynamic> m) {
    List<String> ids(String k) => [
      for (final v in (m[k] as List? ?? const [])) v as String,
    ];
    return LibVerification(
      id: id,
      number: m['number'] as String? ?? id,
      libraryName: m['libraryName'] as String? ?? '',
      status: m['status'] as String? ?? 'counting',
      expected: ids('expected'),
      onLoan: ids('onLoan'),
      scanned: ids('scanned'),
      missing: ids('missing'),
      unexpected: ids('unexpected'),
      investigate: ids('investigate'),
      shelf: m['shelf'] as String?,
      verifiedOn: m['verifiedOn'] as String?,
    );
  }

  final String id;
  final String number;
  final String libraryName;
  final String status;
  final List<String> expected;
  final List<String> onLoan;
  final List<String> scanned;
  final List<String> missing;
  final List<String> unexpected;
  final List<String> investigate;
  final String? shelf;
  final String? verifiedOn;

  bool get isCounting => status == 'counting';
  bool get isSubmitted => status == 'submitted';

  /// Expected copies not scanned yet (final `missing` once submitted).
  List<String> get notYetScanned {
    final s = scanned.toSet();
    return [
      for (final c in expected)
        if (!s.contains(c)) c,
    ];
  }
}
