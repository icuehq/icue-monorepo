import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/src/mirror_search.dart';

void main() {
  test('splits into lowercase words', () {
    expect(searchTerms('Blue Pen'), ['blue', 'pen']);
    expect(searchTerms('ADM/24/7'), ['adm', '24', '7']);
    expect(searchTerms('Café 12'), ['café', '12']);
  });

  test('drops search operators', () {
    expect(searchTerms('"pen" -black *'), ['pen', 'black']);
    expect(searchTerms('pen OR ink'), ['pen', 'or', 'ink']);
    expect(searchTerms('- * "'), isEmpty);
  });
}
