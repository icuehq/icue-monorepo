import 'package:school_library/src/models/library_members.g.dart';

export 'library_members.g.dart';

const fineTypes = {
  'none': 'No fine',
  'per_day': 'Per day overdue',
  'flat': 'Flat amount',
};

extension LibraryPolicyMembers on LibraryPolicy {
  String get appliesTo => switch (memberType) {
    'STUDENT' => 'Students',
    'EMPLOYEE' => 'Employees',
    _ => 'Everyone',
  };

  String get summary =>
      '$maxBooks book${maxBooks == 1 ? '' : 's'} · $loanDays days · '
      '$maxRenewals renewal${maxRenewals == 1 ? '' : 's'}';
}

extension LibraryMemberMembers on LibraryMember {
  bool get isStudent => memberType == 'STUDENT';
  String get label => name.isEmpty
      ? '${isStudent ? 'Student' : 'Employee'} #$personErpId'
      : name;
}

/// Who the members list shows. Staff are the library's `EMPLOYEE` members.
enum MemberKind {
  all('All'),
  student('Students'),
  staff('Staff');

  const MemberKind(this.label);
  final String label;

  /// The stored `memberType`, or null for everyone.
  String? get memberType => switch (this) {
    all => null,
    student => 'STUDENT',
    staff => 'EMPLOYEE',
  };
}
