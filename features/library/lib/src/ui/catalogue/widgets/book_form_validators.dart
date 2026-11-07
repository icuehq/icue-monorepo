import 'package:admin_ui/admin_ui.dart';

/// Field validators of the add / edit book form; they mirror the limits of `library.catalogue.upsert`.
abstract final class BookValidators {
  static String? title(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    return text.length > 200 ? 'At most 200 characters' : null;
  }

  static String? authors(String? value) {
    final authors = splitList(value ?? '');
    if (authors.isEmpty) return 'At least one author is required';
    if (authors.length > 10) return 'At most 10 authors allowed';
    if (authors.any((author) => author.length > 100)) {
      return 'Each author name is at most 100 characters';
    }
    return null;
  }

  static String? keywords(String? value) {
    final keywords = splitList(value ?? '');
    if (keywords.length > 20) return 'At most 20 keywords allowed';
    if (keywords.any((keyword) => keyword.length > 50)) {
      return 'Each keyword is at most 50 characters';
    }
    return null;
  }

  static String? year(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1000 || year > DateTime.now().year + 1) {
      return 'Enter a year between 1000 and ${DateTime.now().year + 1}';
    }
    return null;
  }

  static String? pages(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final pages = int.tryParse(text);
    return pages == null || pages < 1 || pages > 100000
        ? 'Enter a page count from 1 to 100000'
        : null;
  }

  /// An ISBN-10 or ISBN-13 with a correct check digit (hyphens allowed); empty is fine.
  static String? isbn(String? value) {
    final text = (value ?? '').replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d{13}$').hasMatch(text)) {
      var sum = 0;
      for (var index = 0; index < 13; index++) {
        sum += int.parse(text[index]) * (index.isOdd ? 3 : 1);
      }
      return sum % 10 == 0 ? null : 'Invalid ISBN-13 check digit';
    }
    if (RegExp(r'^\d{9}[\dX]$').hasMatch(text)) {
      var sum = 0;
      for (var index = 0; index < 10; index++) {
        sum +=
            (text[index] == 'X' ? 10 : int.parse(text[index])) * (10 - index);
      }
      return sum % 11 == 0 ? null : 'Invalid ISBN-10 check digit';
    }
    return 'Enter a 10 or 13 digit ISBN';
  }
}
