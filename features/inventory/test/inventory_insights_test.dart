import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('every report has a unique key and columns', () {
    expect(
      inventoryReports.map((reportDef) => reportDef.key).toSet().length,
      inventoryReports.length,
    );
    expect(inventoryReports.length, 15);
    expect(
      inventoryReports.every((reportDef) => reportDef.cols.isNotEmpty),
      isTrue,
    );
  });
}
