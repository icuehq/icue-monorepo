import 'package:school_library/src/models/library_verifications.g.dart';

export 'library_verifications.g.dart';

String verificationStatusLabel(String value) => switch (value) {
  'counting' => 'Counting',
  'submitted' => 'To review',
  'approved' => 'Approved',
  _ => value,
};

extension LibraryVerificationMembers on LibraryVerification {
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
