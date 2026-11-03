import 'package:school_library/src/models/library_masters.g.dart';

export 'library_masters.g.dart';

extension LibraryBookMembers on LibraryBook {
  String get authorLine => authors.join(', ');
}
