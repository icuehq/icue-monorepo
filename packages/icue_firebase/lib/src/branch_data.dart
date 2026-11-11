import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? _branchUid;
String? _branchPath;

/// A collection of the branch the signed-in user is working in
/// (`orgs/{orgId}/zones/{zoneId}/branches/{branchId}/{path}`). The branch is the tenant. The token is
/// issued for one active branch, so it is read once per sign-in (a branch switch signs in again).
Future<CollectionReference<Map<String, dynamic>>> branchCollection(
  String path,
) async {
  final user = FirebaseAuth.instance.currentUser!;
  if (_branchUid != user.uid) {
    final claims = (await user.getIdTokenResult()).claims;
    _branchPath =
        'orgs/${claims?['orgId']}/zones/${claims?['zoneId']}/branches/${claims?['branchId']}';
    _branchUid = user.uid;
  }
  return FirebaseFirestore.instance.collection('$_branchPath/$path');
}

/// Plain client CRUD for a master collection under the school ([path]).
///
/// Edits (`id` present) update the document. Creates are keyed by the
/// lowercased `code`, so an existing code is rejected; without a `code` the
/// document gets an auto ID. [onCreate] adds fields
/// that only a new document gets.
Future<void> saveMasterDocument(
  String path,
  Map<String, Object?> data, {
  Map<String, Object?> onCreate = const {},
}) async {
  final fields = {...data};
  final id = fields.remove('id') as String?;
  final collection = await branchCollection(path);
  if (id != null) {
    await collection.doc(id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return;
  }
  final code = fields['code'] as String?;
  final document = collection.doc(code?.trim().toLowerCase());
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
  await (await branchCollection(path)).doc(id).update({
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

/// The signed-in user's resolved permissions in the active branch (`userAccess/{userId}`), shared by every module.
class ModuleAccess {
  const ModuleAccess({this.permissions = const {}});

  factory ModuleAccess.fromMap(Map<String, dynamic> data) =>
      ModuleAccess(permissions: readList<String>(data['permissions']).toSet());

  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
}

/// Readers for Firestore map values: a missing or wrongly typed value becomes a safe default.
List<T> readList<T>(Object? value) =>
    value is List ? List<T>.from(value) : <T>[];

num readNumber(Object? value) => value as num? ?? 0;

double readDouble(Object? value) => readNumber(value).toDouble();

String readString(Object? value) => value == null ? '' : '$value';

const _indiaOffset = Duration(hours: 5, minutes: 30);

/// The India-time calendar day (`yyyy-MM-dd`) of a stored Timestamp; empty when there is none.
String readDay(Object? value) => readDayOrNull(value) ?? '';

/// Same as [readDay], null when there is no Timestamp.
String? readDayOrNull(Object? value) => value is Timestamp
    ? value
          .toDate()
          .toUtc()
          .add(_indiaOffset)
          .toIso8601String()
          .substring(0, 10)
    : null;

/// Firestore value of a calendar day (`yyyy-MM-dd`): a Timestamp at midnight India time.
Timestamp dayTimestamp(String day) => Timestamp.fromDate(
  DateTime.parse('${day}T00:00:00Z').subtract(_indiaOffset),
);

/// Same as [dayTimestamp], null for a missing or empty day.
Timestamp? dayTimestampOrNull(String? day) =>
    day == null || day.isEmpty ? null : dayTimestamp(day);

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
