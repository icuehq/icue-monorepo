List<T> _list<T>(Object? v) => v is List ? List<T>.from(v) : <T>[];

class LibLibrary {
  const LibLibrary({
    required this.id,
    required this.code,
    required this.name,
    required this.campusId,
    required this.staffIds,
    required this.active,
    this.description,
    this.location,
    this.contact,
    this.hours,
  });

  factory LibLibrary.fromMap(String id, Map<String, dynamic> m) => LibLibrary(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    description: m['description'] as String?,
    location: m['location'] as String?,
    staffIds: [for (final n in _list<num>(m['staffIds'])) n.toInt()],
    contact: m['contact'] as String?,
    hours: m['hours'] as String?,
    active: m['status'] != 'inactive',
  );

  final String id;
  final String code;
  final String name;
  final int campusId;
  final String? description;
  final String? location;
  final List<int> staffIds;
  final String? contact;
  final String? hours;
  final bool active;
}

class LibCategory {
  const LibCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    this.description,
    this.parentId,
  });

  factory LibCategory.fromMap(String id, Map<String, dynamic> m) => LibCategory(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    description: m['description'] as String?,
    parentId: m['parentId'] as String?,
    active: m['status'] != 'inactive',
  );

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? parentId;
  final bool active;
}

/// A catalogue title (FRS 11.4). Search rows carry only the list fields, so
/// the detail-only ones (description, pages, class number, keywords) are empty there.
class LibBook {
  const LibBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.categoryId,
    required this.active,
    this.subtitle,
    this.isbn10,
    this.isbn13,
    this.publisher,
    this.edition,
    this.year,
    this.language,
    this.description,
    this.pages,
    this.classNo,
    this.keywords = const [],
  });

  factory LibBook.fromMap(String id, Map<String, dynamic> m) => LibBook(
    id: id,
    title: m['title'] as String? ?? '',
    subtitle: m['subtitle'] as String?,
    authors: _list<String>(m['authors']),
    isbn10: m['isbn10'] as String?,
    isbn13: m['isbn13'] as String?,
    publisher: m['publisher'] as String?,
    edition: m['edition'] as String?,
    year: (m['year'] as num?)?.toInt(),
    language: m['language'] as String?,
    categoryId: m['categoryId'] as String? ?? '',
    description: m['description'] as String?,
    pages: (m['pages'] as num?)?.toInt(),
    classNo: m['classNo'] as String?,
    keywords: _list<String>(m['keywords']),
    active: m['status'] != 'inactive',
  );

  final String id;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? isbn10;
  final String? isbn13;
  final String? publisher;
  final String? edition;
  final int? year;
  final String? language;
  final String categoryId;
  final String? description;
  final int? pages;
  final String? classNo;
  final List<String> keywords;
  final bool active;

  String get authorLine => authors.join(', ');
}

/// The signed-in user's resolved permissions (`userAccess/{uid}`).
class LibAccess {
  const LibAccess({this.perms = const {}, this.campuses = const []});

  factory LibAccess.fromMap(Map<String, dynamic> m) => LibAccess(
    perms: _list<String>(m['perms']).toSet(),
    campuses: [for (final n in _list<num>(m['cmp'])) n.toInt()],
  );

  final Set<String> perms;
  final List<int> campuses;

  bool can(String perm) => perms.contains(perm);
}
