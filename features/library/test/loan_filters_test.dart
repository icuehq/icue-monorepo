import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('issued windows start on the right day', () {
    const today = '2026-03-02';
    expect(LoanIssuedWindow.today.from(today), today);
    expect(LoanIssuedWindow.week.from(today), '2026-02-24');
    expect(LoanIssuedWindow.month.from(today), '2026-02-01');
    expect(LoanIssuedWindow.thisMonth.from(today), '2026-03-01');
  });
}
