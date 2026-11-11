import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';

void main() {
  test('ModuleAccess reads permissions and answers checks', () {
    final access = ModuleAccess.fromMap({
      'permissions': ['inventory.settings'],
    });
    expect(access.can('inventory.settings'), isTrue);
    expect(access.can('inventory.items.manage'), isFalse);
  });

  test('readers turn missing or wrongly typed values into safe defaults', () {
    expect(readNumber(null), 0);
    expect(readDouble(3), 3.0);
    expect(readString(null), '');
    expect(readString(5), '5');
    expect(readList<String>('x'), <String>[]);
    expect(readList<int>([1, 2]), [1, 2]);
  });

  test(
    'a day is stored as midnight India time and read back as the same day',
    () {
      final stamp = dayTimestamp('2026-11-01');
      expect(
        stamp.toDate().toUtc().toIso8601String(),
        '2026-10-31T18:30:00.000Z',
      );
      expect(readDay(stamp), '2026-11-01');
      expect(readDay(null), '');
      expect(readDayOrNull('2026-11-01'), isNull);
      expect(dayTimestampOrNull(''), isNull);
    },
  );
}
