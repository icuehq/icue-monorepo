import 'package:school_library/src/models/library_incidents.g.dart';

export 'library_incidents.g.dart';

String incidentResolutionLabel(String? value) => switch (value) {
  'repaired' => 'Repaired',
  'replaced' => 'Replaced',
  'written_off' => 'Written off',
  'charged' => 'Penalty charged',
  'dismissed' => 'Dismissed',
  _ => value ?? '–',
};

extension LibraryIncidentMembers on LibraryIncident {
  bool get isOpen => status == 'open';
  String? get memberLabel => personErpId == null
      ? null
      : memberName ??
            '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
