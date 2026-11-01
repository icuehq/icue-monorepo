import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A collection of the school the signed-in user belongs to (`schools/{schoolId}/{path}`).
Future<CollectionReference<Map<String, dynamic>>> schoolCollection(
  String path,
) async {
  final tokenResult = await FirebaseAuth.instance.currentUser!
      .getIdTokenResult();
  return FirebaseFirestore.instance.collection(
    'schools/${tokenResult.claims?['schoolId']}/$path',
  );
}

/// The message to show for a failed call: the server's message for a callable error, else the error text.
String callableErrorMessage(Object error) => error is FirebaseFunctionsException
    ? (error.message ?? error.code)
    : error.toString();

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
