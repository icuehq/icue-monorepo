import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? _branchUid;
String? _branchPath;
Future<String>? _resolving;
Future<Object?>? _signIn;

/// Registers an in-flight Firebase sign-in (custom-token exchange). Branch reads wait for it instead of
/// failing with "Not signed in" while it runs, and resolve the branch again from the new token.
void trackFirebaseSignIn(Future<Object?> signIn) {
  _branchUid = null;
  _signIn = signIn;
}

/// The signed-in user's branch path, resolved once per sign-in. Concurrent callers (a dashboard runs a dozen
/// queries at once) share one lookup instead of each forcing its own token refresh.
Future<String> _resolveBranchPath(User user) async {
  var claims = (await user.getIdTokenResult()).claims;
  // Right after first sign-in the cached token may predate the claims; refresh it once.
  if (claims?['branchId'] == null) {
    claims = (await user.getIdTokenResult(true)).claims;
  }
  if (claims?['branchId'] == null) throw StateError('Branch claims missing');
  // Web returns numeric claims as doubles (`8.0`), which would not match the `8` path in the rules.
  String id(String key) {
    final value = claims?[key];
    return value is num ? value.toInt().toString() : '$value';
  }

  return 'orgs/${id('orgId')}/zones/${id('zoneId')}/branches/${id('branchId')}';
}

/// The signed-in user's branch path (`orgs/{orgId}/zones/{zoneId}/branches/{branchId}`). The token is
/// issued for one active branch, so it is read once per sign-in (a branch switch signs in again).
Future<String> branchPath() async {
  // Right after login the Firebase sign-in is still running (it signs out first); wait for it.
  try {
    await _signIn;
  } catch (_) {
    // A failed sign-in surfaces below as "Not signed in".
  }
  // On web `currentUser` is null until Firebase Auth restores the session, so wait for the first auth state.
  final user =
      FirebaseAuth.instance.currentUser ??
      await FirebaseAuth.instance.authStateChanges().first;
  if (user == null) throw StateError('Not signed in');
  if (_branchUid != user.uid) {
    final lookup = _resolving ??= _resolveBranchPath(user);
    try {
      _branchPath = await lookup;
      _branchUid = user.uid;
    } finally {
      _resolving = null;
    }
  }
  return _branchPath ?? (throw StateError('Branch path missing'));
}

/// A collection of the branch the signed-in user is working in (`{branchPath}/{path}`). The branch is the tenant.
Future<CollectionReference<Map<String, dynamic>>> branchCollection(
  String path,
) async => FirebaseFirestore.instance.collection('${await branchPath()}/$path');

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
  _ => _plainText(error.toString()),
};

/// A Firestore error that crossed a transaction (web) arrives as text such as
/// `Error: Dart exception: [cloud_firestore/failed-precondition] Member is blocked`; keep only the message.
String _plainText(String text) =>
    RegExp(r'\[[\w-]+/[\w-]+\]\s*(.+)').firstMatch(text)?.group(1) ?? text;

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
