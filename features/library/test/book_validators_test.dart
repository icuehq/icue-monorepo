import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_form_validators.dart';

void main() {
  test(
    'isbn accepts valid 10 and 13 digit numbers, rejects bad check digits',
    () {
      expect(BookValidators.isbn(''), isNull);
      expect(BookValidators.isbn('0-306-40615-2'), isNull);
      expect(BookValidators.isbn('080442957X'), isNull);
      expect(BookValidators.isbn('978-0-306-40615-7'), isNull);
      expect(BookValidators.isbn('9780306406158'), isNotNull);
      expect(BookValidators.isbn('0306406153'), isNotNull);
      expect(BookValidators.isbn('12345'), isNotNull);
    },
  );
}
