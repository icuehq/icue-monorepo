import 'package:icue_ui/icue_ui.dart';
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
      '${memberType == 'STUDENT' ? 'Student' : 'Employee'} #$personErpId';
}

extension LibraryFineCalculation on LibraryFine {
  /// How the amount was worked out, in words; null when nothing useful was stored.
  String? get calculationLabel {
    final data = fineCalculation;
    if (data == null || data.isEmpty) return null;
    String days(Object? count) => '$count ${count == 1 ? 'day' : 'days'}';
    String rupees(Object? value) => value is num ? value.toRupees() : '-';
    switch (type) {
      case 'overdue':
        final rate = data['fineType'] == 'per_day'
            ? '${rupees(data['fineAmount'])} per day'
            : '${rupees(data['fineAmount'])} flat';
        final cap = data['maxFine'];
        return '${days(data['overdueDays'])} overdue, ${days(data['graceDays'])} grace, $rate'
            '${cap is num && cap > 0 ? ', capped at ${rupees(cap)}' : ''}';
      case 'lost':
        return 'Replacement cost of the lost copy: ${rupees(data['charge'])}';
      case 'damaged':
        final severity = data['severity'];
        return 'Damage charge${severity == null ? '' : ' ($severity damage)'}: ${rupees(data['charge'])}';
      default:
        return null;
    }
  }
}
