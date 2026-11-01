import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/features/inventory/widgets/category_form_sheet.dart';

void main() {
  group('generateCategoryCode', () {
    test('returns empty string for empty or non-alphanumeric input', () {
      expect(generateCategoryCode(''), '');
      expect(generateCategoryCode('   '), '');
      expect(generateCategoryCode('---!@#'), '');
    });

    test('generates 3-char code for single words', () {
      expect(generateCategoryCode('Stationery'), 'STA');
      expect(generateCategoryCode('Furniture'), 'FUR');
      expect(generateCategoryCode('IT'), 'IT');
    });

    test('generates 3-char code for two words', () {
      expect(generateCategoryCode('Classroom supplies'), 'CLS');
      expect(generateCategoryCode('Sports equipment'), 'SPE');
    });

    test('generates acronym for three or more words', () {
      expect(generateCategoryCode('Transport spare parts'), 'TSP');
      expect(generateCategoryCode('Books for distribution'), 'BFD');
    });
  });
}
