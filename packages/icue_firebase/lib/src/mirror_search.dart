import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/branch_data.dart';
import 'package:icue_firebase/src/emulator.dart';

/// Whether text search can run on this build. Firestore Enterprise search (Pipelines) is web-only in the
/// SDK, and the emulator has no text index, so every other platform hides its search boxes.
bool get textSearchSupported => kIsWeb && !usesEmulator;

/// The words of [query], lowercase. Punctuation is dropped so users cannot inject search operators (quotes, -, *, OR).
@visibleForTesting
List<String> searchTerms(String query) => query
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((term) => term.isNotEmpty)
    .toList();

/// One page of whole-word matches from the `search` database (a Functions-written mirror of the branch's
/// documents, architecture §10), sorted by [sortField]; the caller reads full documents from `(default)` if it needs them.
///
/// Narrow the match with `categoryIds` (any of), `arrayHas` (field -> element) and `equals` (field -> value). No words (only punctuation) match nothing.
/// A mirrored document: its ID and its list-row fields.
typedef MirrorRow = ({String id, Map<String, dynamic> data});

Future<({List<MirrorRow> rows, bool hasMore})> searchMirror(
  String collection,
  String query, {
  required String sortField,
  List<String>? categoryIds,
  Map<String, Object> arrayHas = const {},
  Map<String, Object> equals = const {},
  int offset = 0,
  int limit = 25,
}) async {
  final terms = searchTerms(query);
  if (terms.isEmpty) return (rows: const <MirrorRow>[], hasMore: false);
  var pipeline =
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'search')
          .pipeline()
          .collection('${await branchPath()}/$collection')
          .search(
            SearchStage.withQueryExpression(
              Expression.documentMatches(terms.join(' ')),
            ),
          );
  if (categoryIds != null) {
    pipeline = pipeline.where(
      Expression.equalAny(Field('categoryId'), categoryIds),
    );
  }
  for (final MapEntry(:key, :value) in arrayHas.entries) {
    pipeline = pipeline.where(Field(key).arrayContainsValue(value));
  }
  for (final MapEntry(:key, :value) in equals.entries) {
    pipeline = pipeline.where(Field(key).equal(Constant(value)));
  }
  // One extra row tells whether another page exists.
  final snapshot = await pipeline
      .sort(Field(sortField).ascending())
      .offset(offset)
      .limit(limit + 1)
      .execute();
  final rows = [
    for (final row in snapshot.result)
      (id: row.document!.id, data: row.data() ?? <String, dynamic>{}),
  ];
  return (rows: rows.take(limit).toList(), hasMore: rows.length > limit);
}
