import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:auth/src/models/app_settings.dart';
import 'package:auth/src/models/assigned_entities.dart';
import 'package:auth/src/models/branches.dart';
import 'package:auth/src/models/otp_response.dart';
import 'package:auth/src/models/person_types.dart';
import 'package:auth/src/models/role_actions.dart';
import 'package:auth/src/models/user_info.dart';
import 'package:auth/src/services/test_role_actions.dart';
import 'package:auth/src/storage/session_token_provider.dart';
import 'package:auth/src/storage/user_local_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';

/// Centralized authentication and role service for all icue apps.
@lazySingleton
class AuthService {
  AuthService(this.apiClient, this.tokenProvider, this.userLocalStorage);

  final ApiClient apiClient;
  final SessionTokenProvider tokenProvider;
  final UserLocalStorage userLocalStorage;

  /// Requests a login OTP against `/v2.0/getloginotp`.
  Future<OtpResponse> requestOtp(String username) async {
    final response = await apiClient.post<dynamic>(
      '/v2.0/getloginotp',
      data: <String, dynamic>{'username': username},
      options: Options(extra: <String, dynamic>{'no_auth': true}),
    );

    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const UnknownApiException(
        message: 'Unable to process OTP response. Please try again.',
      );
    }

    return OtpResponse.fromJson(data);
  }

  /// Performs user login with OTP against `/v2.0/login`.
  /// Automatically stores the received token and user info into [tokenProvider] and [userLocalStorage].
  Future<UserInfo> login({
    required String username,
    required String password,
  }) async {
    final response = await apiClient.post<dynamic>(
      '/v2.0/login',
      data: <String, dynamic>{'username': username, 'password': password},
      options: Options(extra: <String, dynamic>{'no_auth': true}),
    );

    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const UnknownApiException(
        message: 'Unable to process login response. Please try again.',
      );
    }

    final userInfo = UserInfo.fromJson(data);

    if (userInfo.token.isNotEmpty) {
      tokenProvider.setToken(userInfo.token);
    }

    // Persist full user info in Hive 'userInfo-v2' matching existing app format
    await userLocalStorage.saveUser(userInfo);
    unawaited(ensureFirebaseSession(refresh: true));

    return userInfo;
  }

  Future<bool>? _firebaseSignIn;

  /// Ensures a Firebase user for the stored Node session (custom-token
  /// exchange via `/v1.0/firebaseToken`, then `session-sync`). [refresh]
  /// re-exchanges even when signed in (after every Node login, for fresh
  /// claims). Concurrent calls share one exchange. Best-effort: false on any
  /// failure, so the Node login never depends on Firebase.
  Future<bool> ensureFirebaseSession({bool refresh = false}) async {
    final user = userLocalStorage.getUser();
    if (user == null || Firebase.apps.isEmpty) return false;
    // Web restores the Firebase user asynchronously.
    final current = await FirebaseAuth.instance.authStateChanges().first;
    if (!refresh && current?.uid == user.id.toString()) return true;
    return _firebaseSignIn ??= _exchangeFirebaseToken().whenComplete(
      () => _firebaseSignIn = null,
    );
  }

  Future<bool> _exchangeFirebaseToken() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) await auth.signOut();
      final token = usesEmulator
          ? await _emulatorToken()
          : await _nodeFirebaseToken();
      if (token == null || token.isEmpty) return false;
      final credential = await auth.signInWithCustomToken(token);
      final name = userLocalStorage.getUser()?.name ?? '';
      if (name.isNotEmpty) await credential.user?.updateDisplayName(name);
      await callFunction('session-sync');
      return true;
    } catch (_) {
      // Not logged: errors may carry the custom token. Retried on next call.
      return false;
    }
  }

  Future<String?> _nodeFirebaseToken() async {
    final response = await apiClient.post<dynamic>('/v1.0/firebaseToken');
    final dynamic data = response.data;
    final token = data is Map<String, dynamic> ? data['token'] : null;
    return token is String ? token : null;
  }

  /// Local runs against the emulators: claims built from the Node user and
  /// `getActionsByRole`, as the Node endpoint will (architecture §2). Replace
  /// with the real endpoint once it is live; wardStudentIds/parents are not
  /// covered.
  Future<String?> _emulatorToken() async {
    final user = userLocalStorage.getUser();
    if (user == null) return null;
    List<RoleActions> actions;
    try {
      actions = await getRoleActions();
    } catch (_) {
      actions = userLocalStorage.getRoleActions();
    }
    final branch = userLocalStorage.getSelectedBranch()?.id ?? user.branchId;
    return emulatorCustomToken(user.id.toString(), <String, Object?>{
      'schoolId': user.organizationId,
      'campusIds': <int>[if (branch != 0) branch],
      'hasAllCampuses': false,
      'roleIds': [for (final r in user.roles) r.id],
      'actionIds': [
        for (final action in actions) ...[
          action.id,
          for (final sub in action.subActionItems ?? <RoleActions>[]) sub.id,
        ],
      ],
      'personType': 'staff',
      'personErpId': user.id,
    });
  }

  /// `devices/{uid}/tokens/{sha256(token)}` of the signed-in Firebase user.
  DocumentReference<Map<String, dynamic>>? _pushTokenDoc(String token) {
    if (Firebase.apps.isEmpty) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = sha256.convert(utf8.encode(token)).toString();
    return FirebaseFirestore.instance.doc('devices/$uid/tokens/$id');
  }

  /// Fetches actions permitted for the current user role against `/v1.0/getActionsByRole`.
  /// Sorts by [RoleActions.tabOrder] and caches to Hive box `'getActionsByRole-v2'`.
  Future<List<RoleActions>> getRoleActions() async {
    final response = await apiClient.post<dynamic>('/v1.0/getActionsByRole');

    if (response.statusCode == 202) {
      final actions = withTestRoleActions(<RoleActions>[]);
      await userLocalStorage.saveRoleActions(actions);
      return actions;
    }

    final dynamic data = response.data;
    if (data is! List) {
      return withTestRoleActions(<RoleActions>[]);
    }

    final actions = withTestRoleActions(
      List<RoleActions>.from(
        data.map((x) => RoleActions.fromJson(x as Map<String, dynamic>)),
      )..sort((a, b) => a.tabOrder.compareTo(b.tabOrder)),
    );

    await userLocalStorage.saveRoleActions(actions);
    return actions;
  }

  /// Fetches the branch's admin app settings via `/v1.0/getAdminAppSettings`.
  Future<AppSettings?> getAdminAppSettings() async {
    final response = await apiClient.post<dynamic>('/v1.0/getAdminAppSettings');
    final data = response.data;
    return data is Map<String, dynamic> ? AppSettings.fromJson(data) : null;
  }

  /// Fetches branches for zonal admin/supervisor against `/v1.0/getBranchesByZoneId`.
  Future<List<Branch>> getBranchesByZoneId() async {
    final response = await apiClient.post<dynamic>('/v1.0/getBranchesByZoneId');

    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      return <Branch>[];
    }

    final branchs = Branchs.fromJson(data);
    return branchs.data;
  }

  /// Fetches person categories against `/v1.0/getPersonTypes`.
  /// Caches locally in Hive box `'personTypes-v2'`.
  Future<List<PersonType>> getPersonTypes() async {
    final cached = userLocalStorage.getPersonTypes();
    if (cached.isNotEmpty) {
      return cached;
    }

    final response = await apiClient.post<dynamic>('/v1.0/getPersonTypes');
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      return <PersonType>[];
    }

    final personTypes = PersonTypes.fromJson(data);
    await userLocalStorage.savePersonTypes(personTypes.data);
    return personTypes.data;
  }

  /// Fetches assigned class and section entities against `/v1.0/getAssignedEntities`.
  /// If [forAttendance] is true, filters for `STUDENT` standards.
  Future<List<AssignedEntityClass>> getAssignedEntities({
    bool forAttendance = false,
  }) async {
    final response = await apiClient.post<dynamic>('/v1.0/getAssignedEntities');
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      return <AssignedEntityClass>[];
    }

    final assignedEntities = AssignedEntities.fromJson(data);
    final entities = assignedEntities.data;
    if (entities == null || entities.isEmpty) {
      return <AssignedEntityClass>[];
    }

    final classes = entities.first.classes;
    if (forAttendance) {
      return classes.where((e) => e.standardType == 'STUDENT').toList();
    }
    return classes;
  }

  /// Registers the device's FCM [token] with Node (`/v1.0/updateRegTokens`)
  /// and Firestore (`devices/{uid}/tokens`). Skipped when the same token is
  /// already stored; it is stored only after both writes, so a failure is
  /// retried on next launch. Best-effort.
  Future<void> registerPushToken(String token) async {
    final user = userLocalStorage.getUser();
    if (user == null || userLocalStorage.getFcmToken() == token) return;
    try {
      await apiClient.post<dynamic>(
        '/v1.0/updateRegTokens',
        data: <String, dynamic>{
          'DeviceId': token,
          'Type': 'AdminApp',
          'Id': user.id,
        },
      );
      if (!await ensureFirebaseSession()) return;
      await _pushTokenDoc(token)?.set(<String, Object>{
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'app': 'icueadmin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await userLocalStorage.saveFcmToken(token);
    } catch (_) {
      // Retried on next launch/login since the token isn't stored.
    }
  }

  /// Unregisters the stored FCM token from Node (`/v1.0/removeRegToken`) and
  /// Firestore; best-effort. Must run before Firebase sign-out.
  Future<void> _removePushToken() async {
    final token = userLocalStorage.getFcmToken();
    final user = userLocalStorage.getUser();
    if (token == null || user == null) return;
    try {
      await apiClient.post<dynamic>(
        '/v1.0/removeRegToken',
        data: <String, dynamic>{
          'DeviceId': token,
          'Type': 'AdminApp',
          'Id': user.id,
        },
      );
    } catch (_) {}
    try {
      // Firestore writes queue forever when auth is invalid; never block logout on it.
      await _pushTokenDoc(token)?.delete().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Logs out the user by notifying the server and clearing all Hive storage boxes.
  Future<void> logout() async {
    await _removePushToken();
    try {
      await apiClient.post<dynamic>('/v1.0/logout');
    } catch (_) {
      // Best-effort server notification; always proceed to clear local storage
    } finally {
      await userLocalStorage.clearAll();
      await tokenProvider.clear();
      if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
    }
  }
}
