import 'package:school_library/src/models/library_members.g.dart';

export 'library_members.g.dart';

const fineTypes = {
  'none': 'No fine',
  'per_day': 'Per day overdue',
  'flat': 'Flat amount',
};

extension LibraryPolicyMembers on LibraryPolicy {
  String get appliesTo => memberType == 'student' ? 'Students' : 'Teachers';

  String get summary =>
      '$maxBooks book${maxBooks == 1 ? '' : 's'} · $loanDays days · '
      '$maxRenewals renewal${maxRenewals == 1 ? '' : 's'}';
}

extension LibraryMemberMembers on LibraryMember {
  bool get isStudent => memberType == 'student';
  String get label => name.isEmpty
      ? '${isStudent ? 'Student' : 'Teacher'} #$personErpId'
      : name;
}
