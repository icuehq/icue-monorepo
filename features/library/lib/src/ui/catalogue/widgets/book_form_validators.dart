import 'package:icue_ui/icue_ui.dart';

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
}
