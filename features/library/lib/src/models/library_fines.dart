import 'package:school_library/src/models/library_fines.g.dart';

export 'library_fines.g.dart';

String fineTypeLabel(String value) => switch (value) {
  'overdue' => 'Overdue',
  'lost' => 'Lost book',
  'damaged' => 'Damaged book',
  _ => value,
};

extension LibraryFineMembers on LibraryFine {
  bool get isOutstanding =>
      outstanding > 0 && status != 'waived' && status != 'paid';
  String get memberLabel =>
      memberName ??
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
