import 'package:api_client/api_client.dart';
import 'package:auth/src/models/assigned_entities.dart';
import 'package:auth/src/models/branches.dart';
import 'package:auth/src/models/otp_response.dart';
import 'package:auth/src/models/person_types.dart';
import 'package:auth/src/models/role_actions.dart';
import 'package:auth/src/models/user_info.dart';
import 'package:auth/src/storage/session_token_provider.dart';
import 'package:auth/src/storage/user_local_storage.dart';
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

    return userInfo;
  }

  /// Fetches actions permitted for the current user role against `/v1.0/getActionsByRole`.
  /// Sorts by [RoleActions.tabOrder] and caches to Hive box `'getActionsByRole-v2'`.
  Future<List<RoleActions>> getRoleActions() async {
    final response = await apiClient.post<dynamic>('/v1.0/getActionsByRole');

    if (response.statusCode == 202) {
      await userLocalStorage.saveRoleActions(<RoleActions>[]);
      return <RoleActions>[];
    }

    final dynamic data = response.data;
    if (data is! List) {
      return <RoleActions>[];
    }

    final actions = List<RoleActions>.from(
      data.map((x) => RoleActions.fromJson(x as Map<String, dynamic>)),
    )..sort((a, b) => a.tabOrder.compareTo(b.tabOrder));

    await userLocalStorage.saveRoleActions(actions);
    return actions;
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

  /// Registers the device's FCM [token] with the server (`/v1.0/updateRegTokens`).
  /// Skipped when the same token is already stored; best-effort.
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
      await userLocalStorage.saveFcmToken(token);
    } catch (_) {
      // Retried on next launch/login since the token isn't stored.
    }
  }

  /// Unregisters the stored FCM token (`/v1.0/removeRegToken`); best-effort.
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
    }
  }
}
