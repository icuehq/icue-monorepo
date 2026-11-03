import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Region of every icue Cloud Function.
const functionsRegion = 'asia-south1';

const _transient = {'unavailable', 'deadline-exceeded'};

/// A new idempotency key (Firestore auto-ID; generated locally). Keep it for
/// the whole user action and pass it again when the user retries.
String newRequestId() => FirebaseFirestore.instance.collection('_').doc().id;

/// Calls the callable [name] (e.g. `session-sync`) with a `requestId`.
///
/// Transient failures are retried with the same `requestId`, so the server
/// applies the operation at most once. Returns the callable's raw result.
Future<Object?> callFunction(
  String name, {
  Map<String, Object?> data = const {},
  String? requestId,
  int retries = 2,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: functionsRegion)
      .httpsCallable(name);
  final payload = {...data, 'requestId': requestId ?? newRequestId()};
  for (var attempt = 0; ; attempt++) {
    try {
      return (await callable.call<Object?>(payload)).data;
    } on FirebaseFunctionsException catch (e) {
      if (attempt >= retries || !_transient.contains(e.code)) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 500 << attempt));
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
