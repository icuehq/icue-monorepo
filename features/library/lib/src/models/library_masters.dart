import 'package:school_library/src/models/library_masters.g.dart';

export 'library_masters.g.dart';

extension LibraryBookMembers on LibraryBook {
  String get authorLine => authors.join(', ');
}

extension SchoolLibraryMembers on SchoolLibrary {
  /// Phone and email on one line; empty when neither is set.
  String get contactLine => [phone, email].whereType<String>().join(' · ');
}
