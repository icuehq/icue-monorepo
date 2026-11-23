import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:auth/src/models/app_settings.dart';
import 'package:auth/src/models/assigned_entities.dart';
import 'package:auth/src/models/branches.dart';
import 'package:auth/src/models/otp_response.dart';
import 'package:auth/src/models/person_types.dart';
import 'package:auth/src/models/role_actions.dart';
import 'package:auth/src/models/role_users.dart';
import 'package:auth/src/models/user_info.dart';
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

    return apiClient.parse(
      response,
      (data) => OtpResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Performs user login against [path] (`/v2.0/login` with an OTP, or
  /// `/v1.0/login` with a password).
  /// Automatically stores the received token and user info into [tokenProvider] and [userLocalStorage].
  Future<UserInfo> login({
    required String username,
    required String password,
    String path = '/v2.0/login',
    String? source,
  }) async {
    final response = await apiClient.post<dynamic>(
      path,
      data: <String, dynamic>{
        'username': username,
        'password': password,
        'Source': ?source,
      },
      options: Options(extra: <String, dynamic>{'no_auth': true}),
    );

    final userInfo = apiClient.parse(
      response,
      (data) => UserInfo.fromJson(data as Map<String, dynamic>),
    );

    if (userInfo.token.isNotEmpty) {
      tokenProvider.setToken(userInfo.token);
    }

    // Persist full user info in Hive 'userInfo-v2' matching existing app format
    await userLocalStorage.saveUser(userInfo);
    trackFirebaseSignIn(ensureFirebaseSession(refresh: true));

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
    // A stale persisted user (invalid-refresh-token) errors here: treat as
    // signed out and re-exchange below.
    final User? current = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => FirebaseAuth.instance.currentUser,
        )
        // errors:ok a stale persisted user fails here; it counts as signed out.
        .then<User?>((user) => user, onError: (_) => null);
    if (!refresh && current?.uid == user.id.toString()) return true;
    return _firebaseSignIn ??= _exchangeFirebaseToken().whenComplete(
      () => _firebaseSignIn = null,
    );
  }

  Future<bool> _exchangeFirebaseToken() async {
    try {
      final auth = FirebaseAuth.instance;
      // errors:ok signing out first is best-effort; the exchange below reports its own failure.
      await auth.signOut().catchError((_) {});
      final token = usesEmulator
          ? await _emulatorToken()
          : await _cloudFirebaseToken();
      if (token == null || token.isEmpty) return false;
      final credential = await auth.signInWithCustomToken(token);
      final name = userLocalStorage.getUser()?.name ?? '';
      if (name.isNotEmpty) await credential.user?.updateDisplayName(name);
      await callFunction('session-sync');
      return true;
    } catch (error, stack) {
      reportError(error, stack, 'AuthService._exchangeFirebaseToken');
      debugPrint('Firebase token exchange error: $error');
      return false;
    }
  }

  Future<String?> _cloudFirebaseToken() async {
    final user = userLocalStorage.getUser();
    if (user == null) return null;
    List<RoleActions> actions;
    try {
      actions = await getRoleActions();
    } catch (error, stack) {
      reportError(error, stack, 'AuthService._cloudFirebaseToken');
      actions = userLocalStorage.getRoleActions();
    }
    final branch = userLocalStorage.getSelectedBranch()?.id ?? user.branchId;
    final nodeToken = tokenProvider.currentToken ?? user.token;
    final response = await callFunction(
      'session-token',
      data: <String, Object?>{
        'token': nodeToken,
        'uid': user.id.toString(),
        ..._branchClaims(user, branch),
        'roleIds': [for (final role in user.roles) role.id],
        'actionIds': [
          for (final action in actions) ...[
            action.id,
            for (final subAction in action.subActionItems ?? <RoleActions>[])
              subAction.id,
          ],
        ],
        'personType': 'staff',
        'personErpId': user.id,
      },
    );
    if (response is Map && response['token'] is String) {
      return response['token'] as String;
    }
    return null;
  }

  /// The org → zone → branch the token is issued for. A corporate user is
  /// scoped to the org, everyone else to their branch; the data lives under
  /// the active [branch] only (a switch re-exchanges the token).
  Map<String, Object?> _branchClaims(UserInfo user, int branch) => {
    'orgId': user.organizationId,
    'zoneId': user.zoneId,
    'branchId': branch,
    'scope': user.isCorporate ? 'org' : 'branch',
  };

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
    } catch (error, stack) {
      reportError(error, stack, 'AuthService._emulatorToken');
      actions = userLocalStorage.getRoleActions();
    }
    final branch = userLocalStorage.getSelectedBranch()?.id ?? user.branchId;
    return emulatorCustomToken(user.id.toString(), <String, Object?>{
      ..._branchClaims(user, branch),
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
      const actions = <RoleActions>[];
      await userLocalStorage.saveRoleActions(actions);
      return actions;
    }

    final actions = apiClient.parse(
      response,
      (data) => data is! List
          ? null
          : [
              for (final item
                  in data.cast<Map<String, dynamic>>().toList()..sort(
                    (a, b) => ((a['TabOrder'] ?? 0) as num).compareTo(
                      (b['TabOrder'] ?? 0) as num,
                    ),
                  ))
                RoleActions.fromJson(item),
            ],
    );
    if (actions == null) return <RoleActions>[];

    await userLocalStorage.saveRoleActions(actions);
    return actions;
  }

  /// Users of the current branch holding [roleId] (see [RoleIds]) via
  /// `/v1.0/getUsersByRole`. Organization, zone, branch and source are added
  /// by the API client.
  Future<List<RoleUser>> getUsersByRole(int roleId) async {
    final response = await apiClient.post<dynamic>(
      '/v1.0/getUsersByRole',
      data: <String, dynamic>{'RoleId': roleId},
    );
    return apiClient.parse(response, (data) {
      final users = (data as Map<String, dynamic>)['data'] as List<dynamic>;
      return [
        for (final user in users.cast<Map<String, dynamic>>())
          RoleUser.fromJson(user),
      ];
    });
  }

  /// Fetches the branch's admin app settings via `/v1.0/getAdminAppSettings`.
  Future<AppSettings?> getAdminAppSettings() async {
    final response = await apiClient.post<dynamic>('/v1.0/getAdminAppSettings');
    return apiClient.parse(
      response,
      (data) =>
          data is Map<String, dynamic> ? AppSettings.fromJson(data) : null,
    );
  }

  /// Fetches branches for zonal admin/supervisor against `/v1.0/getBranchesByZoneId`.
  Future<List<Branch>> getBranchesByZoneId() async {
    final response = await apiClient.post<dynamic>('/v1.0/getBranchesByZoneId');

    return apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? Branchs.fromJson(data).data
          : <Branch>[],
    );
  }

  /// Fetches person categories against `/v1.0/getPersonTypes`.
  /// Caches locally in Hive box `'personTypes-v2'`.
  Future<List<PersonType>> getPersonTypes() async {
    final cached = userLocalStorage.getPersonTypes();
    if (cached.isNotEmpty) {
      return cached;
    }

    final response = await apiClient.post<dynamic>('/v1.0/getPersonTypes');
    final personTypes = apiClient.parse(
      response,
      (data) =>
          data is Map<String, dynamic> ? PersonTypes.fromJson(data) : null,
    );
    if (personTypes == null) return <PersonType>[];
    await userLocalStorage.savePersonTypes(personTypes.data);
    return personTypes.data;
  }

  /// Fetches assigned class and section entities against `/v1.0/getAssignedEntities`.
  /// If [forAttendance] is true, filters for `STUDENT` standards.
  Future<List<AssignedEntityClass>> getAssignedEntities({
    bool forAttendance = false,
  }) async {
    final response = await apiClient.post<dynamic>('/v1.0/getAssignedEntities');
    final assignedEntities = apiClient.parse(
      response,
      (data) =>
          data is Map<String, dynamic> ? AssignedEntities.fromJson(data) : null,
    );
    if (assignedEntities == null) return <AssignedEntityClass>[];
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
    } catch (error, stack) {
      reportError(error, stack, 'AuthService.registerPushToken');
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
    } catch (error, stack) {
      reportError(error, stack, 'AuthService._removePushToken');
    }
    try {
      // Firestore writes queue forever when auth is invalid; never block logout on it.
      await _pushTokenDoc(token)?.delete().timeout(const Duration(seconds: 3));
    } catch (error, stack) {
      reportError(error, stack, 'AuthService._removePushToken');
    }
  }

  /// Logs out the user by notifying the server and clearing all Hive storage boxes.
  Future<void> logout() async {
    await _removePushToken();
    try {
      await apiClient.post<dynamic>('/v1.0/logout');
    } catch (error, stack) {
      reportError(error, stack, 'AuthService.logout');
      // Best-effort server notification; always proceed to clear local storage
    } finally {
      await userLocalStorage.clearAll();
      await tokenProvider.clear();
      if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
    }
  }
}
