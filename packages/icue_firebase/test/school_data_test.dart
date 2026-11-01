import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';

void main() {
  test('ModuleAccess reads permissions and campuses and answers checks', () {
    final access = ModuleAccess.fromMap({
      'permissions': ['inventory.settings'],
      'campusIds': [31],
    });
    expect(access.can('inventory.settings'), isTrue);
    expect(access.can('inventory.items.manage'), isFalse);
    expect(access.campusIds, [31]);
    expect(access.hasAllCampuses, isFalse);
    expect(
      ModuleAccess.fromMap({'hasAllCampuses': true}).hasAllCampuses,
      isTrue,
    );
  });

  test('readers turn missing or wrongly typed values into safe defaults', () {
    expect(readNumber(null), 0);
    expect(readDouble(3), 3.0);
    expect(readString(null), '');
    expect(readString(5), '5');
    expect(readList<String>('x'), <String>[]);
    expect(readList<int>([1, 2]), [1, 2]);
  });

  test('readDay keeps the day of a stored string and ignores other values', () {
    expect(readDay('2026-11-01T10:00'), '2026-11-01');
    expect(readDay(null), '');
  });
}
