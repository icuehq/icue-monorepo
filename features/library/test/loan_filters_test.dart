import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('last month spans the whole previous month', () {
    final range = calculateRangeForPreset(LibraryDatePreset.lastMonth);
    expect(range.start.day, 1);
    expect(range.end.add(const Duration(days: 1)).day, 1);
    expect(range.end.isBefore(DateTime.now()), isTrue);
  });
}
