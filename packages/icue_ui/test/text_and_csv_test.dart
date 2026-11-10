import 'package:icue_ui/icue_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'status codes become readable text, with overrides and a dash for none',
    () {
      expect(humanizeStatus('partially_paid'), 'Partially paid');
      expect(
        humanizeStatus('dispatched', overrides: {'dispatched': 'In transit'}),
        'In transit',
      );
      expect(humanizeStatus(null), '–');
    },
  );

  test('CSV quotes only cells that need it', () {
    expect(
      toCsv(
        ['A', 'B'],
        [
          ['x,y', 'say "hi"'],
          ['1', ''],
        ],
      ),
      'A,B\n"x,y","say ""hi"""\n1,',
    );
  });

  test(
    'CSV parses what toCsv writes, plus CRLF, blank lines and short rows',
    () {
      final text = toCsv(
        ['code', 'name'],
        [
          ['A', 'say "hi", ok'],
          ['B', 'two\nlines'],
        ],
      );
      expect(parseCsv(text), [
        {'code': 'A', 'name': 'say "hi", ok'},
        {'code': 'B', 'name': 'two\nlines'},
      ]);
      expect(parseCsv(' code , name \r\n\r\nX\r\n'), [
        {'code': 'X', 'name': ''},
      ]);
      expect(parseCsv(''), isEmpty);
    },
  );
}
