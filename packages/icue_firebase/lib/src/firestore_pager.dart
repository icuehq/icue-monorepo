import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Fetches one page: Firestore sources start after [after], offset-based
/// sources (search callables) skip [offset] rows.
typedef PageFetch<T> = Future<PagedResult<T>> Function({
  required DocumentSnapshot<Map<String, dynamic>>? after,
  required int offset,
  required int limit,
});

/// Page-by-page (or append-on-scroll) paging over a Firestore query or any
/// [PageFetch].
///
/// Keeps the start cursor of every page walked so far, so [previous] re-reads
/// the earlier page instead of holding every row in memory. An older response
/// never overwrites a newer one.
class FirestorePager<T> extends ChangeNotifier {
  FirestorePager({this.pageSize = 10});

  int pageSize;

  /// Rows of the current page, or every row loaded so far after `next(append: true)`.
  final List<T> items = [];
  int pageIndex = 0;
  bool loading = false;
  bool hasNext = false;
  bool get hasPrevious => pageIndex > 0;

  /// Rows matching the source, when it can count them.
  int? total;
  Object? error;

  PageFetch<T>? _fetch;

  /// `_starts[i]` is the cursor page `i` starts after (null for the first).
  final List<DocumentSnapshot<Map<String, dynamic>>?> _starts = [null];
  int _generation = 0;
  int _loadGeneration = 0;
  Future<void> Function()? _failed;

  /// Pages [query] (already filtered and ordered) from the first page and counts its rows.
  Future<void> loadQuery(
    Query<Map<String, dynamic>> query,
    T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc,
  ) => load(
    ({required after, required offset, required limit}) =>
        fetchPage(query, fromDoc, after: after, limit: limit),
    count: () async => (await query.count().get()).count ?? 0,
  );

  /// Pages [fetch] from the first page; [count] (if any) fills [total].
  Future<void> load(PageFetch<T> fetch, {Future<int> Function()? count}) {
    _fetch = fetch;
    total = null;
    // Page moves within this source keep its count; only a newer load drops it.
    final load = ++_loadGeneration;
    if (count != null) {
      count().then((value) {
        if (load != _loadGeneration) return;
        total = value;
        notifyListeners();
      }, onError: (Object _) {});
    }
    return _go(0);
  }

  /// Re-reads from the first page with the same source.
  Future<void> reload() => _fetch == null ? Future.value() : _go(0);

  /// Repeats the page load that failed (see [error]).
  Future<void> retry() => _failed?.call() ?? reload();

  /// The next page; [append] adds it to [items] (infinite scroll).
  Future<void> next({bool append = false}) async {
    if (!hasNext || loading) return;
    await _go(pageIndex + 1, append: append);
  }

  Future<void> previous() async {
    if (!hasPrevious) return;
    await _go(pageIndex - 1);
  }

  /// Changes the page size and returns to the first page.
  Future<void> setPageSize(int size) {
    pageSize = size;
    return reload();
  }

  Future<void> _go(int page, {bool append = false}) async {
    final fetch = _fetch!;
    final generation = ++_generation;
    if (page == 0) _starts.length = 1;
    loading = true;
    error = null;
    _failed = null;
    notifyListeners();
    try {
      final result = await fetch(
        after: _starts[page],
        offset: append ? items.length : page * pageSize,
        limit: pageSize,
      );
      if (generation != _generation) return;
      if (page > 0 && result.items.isEmpty) {
        // Rows were removed since hasNext was read: stay on the last real page.
        hasNext = false;
        return;
      }
      if (!append) items.clear();
      items.addAll(result.items);
      pageIndex = page;
      hasNext = result.hasMore;
      // The last page fixes the total when the source cannot count.
      if (!hasNext) {
        total ??= append ? items.length : page * pageSize + items.length;
      }
      if (_starts.length > page + 1) _starts.length = page + 1;
      _starts.add(result.cursor);
    } catch (caught) {
      if (generation != _generation) return;
      error = caught;
      _failed = () => _go(page, append: append);
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

/// One page of a cursor-paginated query.
class PagedResult<T> {
  const PagedResult(this.items, this.cursor, {required this.hasMore});

  final List<T> items;

  /// Pass as `after` to [fetchPage] for the next page.
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

/// Fetches [limit] docs of [query] after [after]; reads one extra to know
/// whether another page exists.
Future<PagedResult<T>> fetchPage<T>(
  Query<Map<String, dynamic>> query,
  T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc, {
  DocumentSnapshot<Map<String, dynamic>>? after,
  int limit = 25,
}) async {
  var q = query.limit(limit + 1);
  if (after != null) q = q.startAfterDocument(after);
  final docs = (await q.get()).docs;
  final page = docs.take(limit).toList();
  return PagedResult(
    page.map(fromDoc).toList(),
    page.isEmpty ? after : page.last,
    hasMore: docs.length > limit,
  );
}
