import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? _schoolUid;
Object? _schoolId;

/// A collection of the school the signed-in user belongs to (`schools/{schoolId}/{path}`).
/// The school never changes for a user, so the token is read once per sign-in.
Future<CollectionReference<Map<String, dynamic>>> schoolCollection(
  String path,
) async {
  final user = FirebaseAuth.instance.currentUser!;
  if (_schoolUid != user.uid) {
    _schoolId = (await user.getIdTokenResult()).claims?['schoolId'];
    _schoolUid = user.uid;
  }
  return FirebaseFirestore.instance.collection('schools/$_schoolId/$path');
}

/// Plain client CRUD for a master collection under the school ([path]).
///
/// Edits (`id` present) update the document. Creates are keyed by the
/// lowercased `code`, so an existing code is rejected. [onCreate] adds fields
/// that only a new document gets.
Future<void> saveMasterDocument(
  String path,
  Map<String, Object?> data, {
  Map<String, Object?> onCreate = const {},
}) async {
  final fields = {...data};
  final id = fields.remove('id') as String?;
  final collection = await schoolCollection(path);
  if (id != null) {
    await collection.doc(id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return;
  }
  final code = fields['code']! as String;
  final document = collection.doc(code.trim().toLowerCase());
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    if ((await transaction.get(document)).exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'already-exists',
        message: '"$code" already exists',
      );
    }
    transaction.set(document, {
      'status': 'active',
      ...fields,
      ...onCreate,
      'createdBy': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}

/// Activates or deactivates the master [id] in [path].
Future<void> setMasterActive(
  String path,
  String id, {
  required bool active,
}) async {
  await (await schoolCollection(path)).doc(id).update({
    'status': active ? 'active' : 'inactive',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// The message to show for a failed call: the server's message for a callable error, else the error text.
String callableErrorMessage(Object error) => switch (error) {
  FirebaseFunctionsException(:final message, :final code) => message ?? code,
  FirebaseException(:final message, :final code) => message ?? code,
  _ => error.toString(),
};

/// Implemented by providers that keep the message of their last failed call.
abstract interface class ErrorReporting {
  String? get errorMessage;
}

/// The signed-in user's resolved permissions and campuses (`userAccess/{userId}`), shared by every module.
class ModuleAccess {
  const ModuleAccess({
    this.permissions = const {},
    this.campusIds = const [],
    this.hasAllCampuses = false,
  });

  factory ModuleAccess.fromMap(Map<String, dynamic> data) => ModuleAccess(
    permissions: readList<String>(data['permissions']).toSet(),
    campusIds: [for (final id in readList<num>(data['campusIds'])) id.toInt()],
    hasAllCampuses: data['hasAllCampuses'] == true,
  );

  final Set<String> permissions;
  final List<int> campusIds;
  final bool hasAllCampuses;

  bool can(String permission) => permissions.contains(permission);

  /// Firestore rules need a campus filter on every list unless the user sees all campuses.
  /// Returns null when the user has no campus (the list would be empty).
  Query<Map<String, dynamic>>? restrictToCampuses(
    Query<Map<String, dynamic>> query, {
    String field = 'campusId',
  }) => hasAllCampuses
      ? query
      : campusIds.isEmpty
      ? null
      : query.where(field, whereIn: campusIds);
}

/// Readers for Firestore map values: a missing or wrongly typed value becomes a safe default.
List<T> readList<T>(Object? value) =>
    value is List ? List<T>.from(value) : <T>[];

num readNumber(Object? value) => value as num? ?? 0;

double readDouble(Object? value) => readNumber(value).toDouble();

String readString(Object? value) => value == null ? '' : '$value';

/// A calendar day (`yyyy-MM-dd`) from a stored day string or a timestamp; empty when there is none.
String readDay(Object? value) {
  if (value is String) {
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
  return value is Timestamp
      ? value.toDate().toIso8601String().substring(0, 10)
      : '';
}

/// One document of a report as stored in Firestore.
typedef ReportRow = Map<String, dynamic>;

/// One report column: a heading and how to show a row's cell. [Names] resolves IDs to names (items, stores, libraries…).
class ReportColumn<Names> {
  const ReportColumn(this.label, this.cell, {this.sum = false});

  final String label;
  final String Function(ReportRow row, Names names) cell;

  /// Total shown under the table (cells must be numbers).
  final bool sum;
}

/// Today's calendar day in India Standard Time (`yyyy-MM-dd`), as the backend dates records.
String todayIST() => DateTime.now()
    .toUtc()
    .add(const Duration(hours: 5, minutes: 30))
    .toIso8601String()
    .substring(0, 10);

/// Newest [limit] documents leaving or arriving on the user's campuses (`campusId` / `toCampusId`),
/// merged newest first. Rules need the campus filter on both sides, so the two lists are fetched apart.
Future<List<T>> fetchCampusBothSides<T>(
  Query<Map<String, dynamic>> base,
  ModuleAccess access,
  T Function(String id, Map<String, dynamic> data) parse,
  DateTime? Function(T item) createdAt, {
  int limit = 50,
}) async {
  final queries = [
    access.restrictToCampuses(base),
    if (!access.hasAllCampuses)
      access.restrictToCampuses(base, field: 'toCampusId'),
  ];
  final byId = <String, T>{};
  for (final query in queries.whereType<Query<Map<String, dynamic>>>()) {
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    for (final document in snapshot.docs) {
      byId[document.id] = parse(document.id, document.data());
    }
  }
  return byId.values.toList()..sort(
    (first, second) => (createdAt(second) ?? DateTime(0)).compareTo(
      createdAt(first) ?? DateTime(0),
    ),
  );
}
