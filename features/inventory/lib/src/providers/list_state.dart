import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';

typedef ListQuery = Query<Map<String, dynamic>>;

/// [base] narrowed to one [status] and, when [search] is set, to the rows whose
/// [searchField] starts with it (ordered by that field); otherwise newest first.
/// Case follows how the field is stored: [upperCase] for generated numbers like `PO/2025-26/1`.
ListQuery filteredQuery(
  ListQuery base, {
  String? status,
  String statusField = 'status',
  String search = '',
  String searchField = 'number',
  bool upperCase = true,
}) {
  var query = base;
  if (status != null) query = query.where(statusField, isEqualTo: status);
  if (search.isEmpty) return query.orderBy('createdAt', descending: true);
  final prefix = upperCase ? search.toUpperCase() : search;
  return query
      .where(searchField, isGreaterThanOrEqualTo: prefix)
      .where(searchField, isLessThan: '$prefix')
      .orderBy(searchField);
}

/// One paged list page: its status filter, search text and Firestore pager.
/// Every change reloads from the first page; [onChange] rebuilds listeners.
class ListState<T> {
  ListState({
    required this.query,
    required this.fromDocument,
    required this.onChange,
    this.afterPage,
  }) {
    pager.addListener(_pagerChanged);
  }

  final Future<ListQuery> Function(String? status, String search) query;
  final T Function(DocumentSnapshot<Map<String, dynamic>> document)
  fromDocument;
  final VoidCallback onChange;

  /// Runs when rows arrive (first page and "Load more"), e.g. to fetch item names.
  final Future<void> Function(List<T> items)? afterPage;

  final pager = FirestorePager<T>()..loading = true;
  String? status;
  String search = '';
  int _seen = 0;

  bool get filtered => status != null || search.isNotEmpty;

  void _pagerChanged() {
    onChange();
    if (pager.loading || pager.items.length == _seen) return;
    _seen = pager.items.length;
    afterPage?.call(pager.items).then((_) => onChange());
  }

  Future<void> load() async {
    _seen = 0;
    await pager.loadQuery(await query(status, search), fromDocument);
  }

  Future<void> setStatus(String? value) {
    status = value;
    return load();
  }

  Future<void> setSearch(String value) {
    search = value.trim();
    return load();
  }

  Future<void> clear() {
    status = null;
    search = '';
    return load();
  }
}
