import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../models/assigned_entities.dart';
import '../models/branches.dart';
import '../models/person_types.dart';
import '../models/role_actions.dart';
import '../models/user_info.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../services/injectable.dart';
import '../services/notification_service.dart';
import '../utils/app_utils.dart';
import '../utils/navigation/app_router.dart';

@lazySingleton
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._apiClient);

  List<AssignedEntityClass> assignedEntityClasses = [];
  List<Branch> branches = [];
  bool loading = false;
  bool otpSent = false;
  List<PersonType> personTypes = [];
  List<RoleActions> roleActions = [];
  UserInfo? user;

  final ApiClient _apiClient;

  Future<void> sendLoginOtp(BuildContext context, String username) async {
    AppUtils.showLoadingDialog(context, 'Sending OTP... Please wait...');
    try {
      final response = await _apiClient.post(
        '/v2.0/getloginotp',
        data: {'username': username},
      );
      if (response.statusCode == 200) {
        otpSent = true;
        notifyListeners();
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getloginotp', error, stack);
      }
    } finally {
      AppUtils.hideLoadingDialog(context);
    }
  }

  void resetOtpSent() {
    otpSent = false;
    notifyListeners();
  }

  Future<void> login(
    BuildContext context,
    String username,
    String password,
  ) async {
    AppUtils.showLoadingDialog(context, 'Authenticating... Please wait...');
    try {
      final response = await _apiClient.post(
        '/v2.0/login',
        data: {'username': username, 'password': password},
      );
      user = UserInfo.fromJson(response.data as Map<String, dynamic>);
      if (user != null) {
        resetOtpSent();
        await HiveService.userInfoBox.clear();
        await HiveService.userInfoBox.add(user!);
        // If the user is zonal admin, navigate to branches page
        if (user?.roles.firstOrNull?.name.toLowerCase() ==
            'Fleet_ZonalAdmin'.toLowerCase()) {
          AppUtils.hideLoadingDialog(context);
          // Use safe navigation - appRouter.go doesn't require a context
          appRouter.go('/branches');
          return;
        }
        AppUtils.hideLoadingDialog(context);
        await getRoleActions(context);
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/login', error, stack);
      }
      AppUtils.hideLoadingDialog(context);
    }
  }

  Future<void> getRoleActions(
    BuildContext context, {
    bool isSplash = false,
  }) async {
    final userInfo = HiveService.userInfoBox.values.toList();
    if (userInfo.isEmpty) {
      await HiveService.clearAll();
      // Use safe navigation - appRouter.go doesn't require a context
      appRouter.go('/login');
      return;
    }
    final roleName = userInfo.firstOrNull?.roles.firstOrNull?.name
        .toLowerCase();
    if (HiveService.zonalBranch.get('selected') == null &&
        (roleName == 'Fleet_ZonalAdmin'.toLowerCase() ||
            roleName == 'Fleet_ZonalSupervisor'.toLowerCase())) {
      // Use safe navigation - appRouter.go doesn't require a context
      appRouter.go('/branches');
      return;
    }
    if (!isSplash) AppUtils.showLoadingDialog(context, 'Please wait...');
    try {
      final response = await _apiClient.post('/v1.0/getActionsByRole');
      if (response.statusCode == 202) {
        roleActions = [];
      } else {
        roleActions = List<RoleActions>.from(
          (response.data as List).map(
            (x) => RoleActions.fromJson(x as Map<String, dynamic>),
          ),
        );
        roleActions.sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
      }
      await HiveService.getActionsByRoleBox.clear();
      await HiveService.getActionsByRoleBox.addAll(roleActions);
      // Use safe navigation - appRouter.go doesn't require a context
      appRouter.go('/');
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getActionsByRole', error, stack);
      }
    } finally {
      if (!isSplash) AppUtils.hideLoadingDialog(context);
    }
  }

  Future<void> getBranchesByZoneId() async {
    loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post('/v1.0/getBranchesByZoneId');
      final data = Branchs.fromJson(response.data as Map<String, dynamic>);
      branches = data.data;
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getBranchesByZoneId', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    AppUtils.showLoadingDialog(context, 'Logging out... Please wait...');
    try {
      await removeRegToken();
      await _apiClient.post('/v1.0/logout');
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/logout', error, stack);
      }
    } finally {
      await HiveService.clearAll();
      await getIt<NotificationService>().dispose();
      _apiClient.invalidateSessionCache();

      user = null;
      roleActions = [];
      branches = [];
      assignedEntityClasses = [];
      personTypes = [];
      otpSent = false;

      // Use safe navigation - appRouter.go doesn't require a context
      appRouter.go('/login');
      AppUtils.hideLoadingDialog(context);
    }
  }

  Future<void> getPersonTypes(BuildContext context) async {
    loading = true;
    notifyListeners();
    try {
      personTypes = HiveService.personTypesBox.values.toList();
      if (personTypes.isEmpty) {
        final response = await _apiClient.post('/v1.0/getPersonTypes');
        final data = PersonTypes.fromJson(
          response.data as Map<String, dynamic>,
        );
        personTypes = data.data;
        await HiveService.personTypesBox.addAll(personTypes);
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getPersonTypes', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> getAssignedEntities(
    BuildContext context, {
    bool forAttendance = false,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post('/v1.0/getAssignedEntities');
      final data = AssignedEntities.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (data.data != null && data.data!.isNotEmpty) {
        assignedEntityClasses = forAttendance
            ? data.data!.first.classes
                  .where((e) => e.standardType == 'STUDENT')
                  .toList()
            : data.data!.first.classes;
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getAssignedEntities', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateRegTokens(String token) async {
    final userInfo = HiveService.userInfoBox.values.toList();
    try {
      await _apiClient.post(
        '/v1.0/updateRegTokens',
        data: {
          'DeviceId': token,
          'Type': 'AdminApp',
          'Id': userInfo.firstOrNull?.id,
        },
      );
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/updateRegTokens', error, stack);
      }
    }
  }

  Future<void> removeRegToken() async {
    final userInfo = HiveService.userInfoBox.values.toList();
    final token = HiveService.fcmTokenBox.get('fcmtoken');
    try {
      await _apiClient.post(
        '/v1.0/removeRegToken',
        data: {
          'DeviceId': token,
          'Type': 'AdminApp',
          'Id': userInfo.firstOrNull?.id,
        },
      );
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/removeRegToken', error, stack);
      }
    }
  }

  Future<void> testPushNotification() async {
    final userInfo = HiveService.userInfoBox.values.toList();
    final token = HiveService.fcmTokenBox.get('fcmtoken');
    try {
      await _apiClient.post(
        '/v1.0/sendTestPush',
        data: {
          'UserId': userInfo.firstOrNull?.id,
          'Source': 'adminapp',
          'Title': 'Tesh Push from backend',
          'Message': 'sendTestPush from backend',
          'Action': 'Track',
          'ClickAction': 0,
          'DeviceIds': [token],
        },
      );
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/sendTestPush', error, stack);
      }
    }
  }
}
