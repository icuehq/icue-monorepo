import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/lib_masters.dart';

/// Library masters: reads from Firestore, writes through callables.
@lazySingleton
class LibraryService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final user = FirebaseAuth.instance.currentUser!;
    final sid = (await user.getIdTokenResult()).claims?['sid'];
    return FirebaseFirestore.instance.collection('schools/$sid/$path');
  }

  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> m) parse,
  ) async {
    final snap = await (await _coll(path)).get();
    return [for (final d in snap.docs) parse(d.id, d.data())];
  }

  Future<LibAccess> access() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await (await _coll('userAccess')).doc(user.uid).get();
    return LibAccess.fromMap(doc.data() ?? {});
  }

  Future<List<LibLibrary>> libraries() async =>
      (await _all('libLibraries', LibLibrary.fromMap))
        ..sort((a, b) => a.code.compareTo(b.code));

  Future<List<LibCategory>> categories() async =>
      (await _all('libCategories', LibCategory.fromMap))
        ..sort((a, b) => a.code.compareTo(b.code));

  /// A page of titles by title, optionally within [categoryId] (Firestore query).
  Future<PagedResult<LibBook>> books({
    String? categoryId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> q = await _coll('libCatalogue');
    if (categoryId != null) q = q.where('categoryId', isEqualTo: categoryId);
    return fetchPage(
      q.orderBy('title'),
      (d) => LibBook.fromMap(d.id, d.data()!),
      after: after,
    );
  }

  /// Whole-word search by title, author, publisher or keyword, or an exact ISBN (Functions).
  Future<({List<LibBook> items, bool hasMore})> searchBooks(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    final res = await callFunction(
      'lib-catalogue-search',
      data: {
        'q': query,
        'categoryId': ?categoryId,
        'offset': offset,
        'limit': limit,
      },
    ) as Map<Object?, Object?>;
    return (
      items: [
        for (final r in res['items']! as List<Object?>)
          LibBook.fromMap(
            (r! as Map)['id'] as String,
            Map<String, dynamic>.from(r as Map),
          ),
      ],
      hasMore: res['hasMore'] == true,
    );
  }

  Future<LibBook?> book(String id) async {
    final d = await (await _coll('libCatalogue')).doc(id).get();
    return d.exists ? LibBook.fromMap(d.id, d.data()!) : null;
  }

  // --- writes: callables, same requestId on user retry --------------------

  Future<void> seedDefaults() => _call('lib-seedDefaults', {});

  Future<void> saveLibrary(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-library-upsert', data, requestId);

  Future<void> setLibraryActive(String id, {required bool active}) =>
      _call('lib-library-setStatus', _status(id, active));

  Future<void> saveCategory(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-category-upsert', data, requestId);

  Future<void> setCategoryActive(String id, {required bool active}) =>
      _call('lib-category-setStatus', _status(id, active));

  Future<void> saveBook(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-catalogue-upsert', data, requestId);

  Future<void> setBookActive(String id, {required bool active}) =>
      _call('lib-catalogue-setStatus', _status(id, active));

  Map<String, Object?> _status(String id, bool active) => {
    'id': id,
    'status': active ? 'active' : 'inactive',
  };

  Future<void> _call(
    String name,
    Map<String, Object?> data, [
    String? requestId,
  ]) async {
    await callFunction(name, data: data, requestId: requestId);
  }
}
