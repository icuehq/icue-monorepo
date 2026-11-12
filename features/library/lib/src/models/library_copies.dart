import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/src/models/library_copies.g.dart';

export 'library_copies.g.dart';

const copyConditions = ['good', 'fair', 'poor'];

extension LibraryCopyMembers on LibraryCopy {
  /// Lost and withdrawn copies are final; issued/in-transit belong to circulation.
  bool get canChangeStatus =>
      manualCopyStatuses.contains(status) &&
      !terminalCopyStatuses.contains(status);
}
