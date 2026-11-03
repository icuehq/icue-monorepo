import 'package:school_library/src/models/library_copies.g.dart';

export 'library_copies.g.dart';

const copyConditions = ['good', 'fair', 'poor'];

/// Statuses a librarian may set by hand (the callable rejects the rest).
const copyManualStatuses = [
  'available',
  'under_maintenance',
  'damaged',
  'lost',
  'withdrawn',
];

extension LibraryCopyMembers on LibraryCopy {
  /// Lost and withdrawn copies are final; issued/reserved/in-transit belong to circulation.
  bool get canChangeStatus =>
      copyManualStatuses.contains(status) &&
      status != 'lost' &&
      status != 'withdrawn';
}
