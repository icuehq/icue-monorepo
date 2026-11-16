import 'package:school_library/src/models/library_incidents.g.dart';

export 'library_incidents.g.dart';

String incidentResolutionLabel(String? value) => switch (value) {
  'found' => 'Book found',
  'replaced' => 'New book given',
  'not_recovered' => 'Lost for good',
  'repaired' => 'Repaired',
  'written_off' => 'Cannot be repaired',
  'no_damage' => 'Book was fine',
  _ => value ?? '–',
};

extension LibraryIncidentMembers on LibraryIncident {
  bool get isOpen => status == 'open';
  String? get memberLabel => personErpId == null
      ? null
      : memberName ??
            '${memberType == 'STUDENT' ? 'Student' : 'Employee'} #$personErpId';
}
