import 'dart:async';

import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/services/device_info_service.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:injectable/injectable.dart';

@lazySingleton

/// Auth lifecycle and current user state. Validates credentials and caches
/// the authenticated [User] in the [SessionService].
class UserProvider extends ChangeNotifier {
  UserProvider(
    this._sessionService, {
    required ApiClient apiClient,
    required DeviceInfoService deviceInfoService,
  })  : _apiClient = apiClient,
        _deviceInfoService = deviceInfoService {
    _apiClient.onTokenRefreshed = notifyListeners;
  }

  String? errorMessage;

  final ApiClient _apiClient;
  final DeviceInfoService _deviceInfoService;
  final SessionService _sessionService;
  final Map<String, Future<User?>> _inFlightAuth = {};

  User? get user => _sessionService.user;

  /// Validates the current API user and identification number.
  ///
  /// On success, updates the session user; on failure, sets [errorMessage].
  Future<void> validateUserAuth() async {
    final targetId = _sessionService.identificationNo;
    if (targetId == null || targetId.isEmpty) {
      errorMessage = 'No student identification number provided.';
      notifyListeners();
      return;
    }

    if (_sessionService.token != null && _sessionService.token!.isNotEmpty) {
      notifyListeners();
      return;
    }

    errorMessage = null;
    final student = await authenticateStudent(targetId);

    // Guard: Discard response if active student changed while awaiting network
    if (_sessionService.identificationNo != targetId) {
      log('validateUserAuth response discarded for $targetId (active: ${_sessionService.identificationNo})');
      return;
    }

    if (student != null) {
      errorMessage = null;
    }
    notifyListeners();
  }

  /// Authenticates a specific student identification number with the backend
  /// without clobbering the currently active student session in [_sessionService].
  ///
  /// Returns the authenticated [User] on success, or `null` on failure.
  Future<User?> authenticateStudent(String studentIdentificationNo) async {
    if (studentIdentificationNo.isEmpty) return null;

    final cached =
        await _sessionService.loadUserForStudent(studentIdentificationNo);
    if (cached != null && cached.token != null && cached.token!.isNotEmpty) {
      return cached;
    }

    if (_inFlightAuth.containsKey(studentIdentificationNo)) {
      return _inFlightAuth[studentIdentificationNo]!;
    }

    final future = _executeAuth(studentIdentificationNo);
    _inFlightAuth[studentIdentificationNo] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlightAuth.remove(studentIdentificationNo));
    }
  }

  Future<User?> _executeAuth(String studentIdentificationNo) async {
    try {
      final deviceInfo = await _deviceInfoService.getDeviceInfo();
      final result = await _apiClient.postJson<User>(
        ApiRoutes.validateUserAuth,
        body: {
          'APIUser': _sessionService.apiUser,
          'IdentificationNo': studentIdentificationNo,
          ...deviceInfo,
        },
        decoder: (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (result.isSuccess && result.data != null) {
        _sessionService.setUserForStudent(studentIdentificationNo, result.data);
        return result.data;
      } else {
        log(
          'authenticateStudent failed [$studentIdentificationNo] [${result.statusCode}]: ${result.error?.message}',
        );
        errorMessage =
            result.error?.message ?? 'Something went wrong. Please try again.';
        return null;
      }
    } on DioException catch (e) {
      log('authenticateStudent network error', error: e);
      errorMessage = e.message ?? 'Something went wrong. Please try again.';
      return null;
    } catch (error, stack) {
      log('authenticateStudent error', error: error, stackTrace: stack);
      errorMessage = 'An unexpected error occurred. Please try again.';
      return null;
    }
  }

  /// Sends push token registration to the iCue backend.
  ///
  /// Returns `true` if the backend successfully confirmed the token registration.
  Future<bool> updateRegTokens(
    String token, {
    int? studentId,
    String? bearerToken,
  }) async {
    try {
      final targetStudentId = studentId ?? user?.id;
      if (targetStudentId == null) {
        log('updateRegTokens skipped: user/student ID is missing.');
        return false;
      }

      final result = await _apiClient.postJson<dynamic>(
        ApiRoutes.updateRegTokens,
        body: {
          'DeviceId': token,
          'Type': 'ParentSdk',
          'Id': [targetStudentId],
          'StudentId': targetStudentId,
        },
        headers: bearerToken != null
            ? {'Authorization': 'Bearer $bearerToken'}
            : null,
      );
      if (!result.isSuccess) {
        log(
          'updateRegTokens failed [${result.statusCode}]: ${result.error?.message}',
        );
        return false;
      }
      return true;
    } on DioException catch (e) {
      log('updateRegTokens network error', error: e);
      return false;
    } catch (error, stack) {
      log('updateRegTokens error', error: error, stackTrace: stack);
      return false;
    }
  }

  /// Unregisters student/token mapping on the iCue backend.
  ///
  /// Returns `true` if the unregistration request succeeded.
  Future<bool> logout({
    String? token,
    dynamic studentId,
    String? mobileNumber,
  }) async {
    try {
      final fcmToken = token ?? _sessionService.fcmToken;
      final student = user;

      int? numericStudentId;
      if (studentId is int) {
        numericStudentId = studentId;
      } else if (studentId is String) {
        numericStudentId = int.tryParse(studentId);
        if (numericStudentId == null) {
          final studentObj = _sessionService.getUserForStudent(studentId) ??
              await _sessionService.loadUserForStudent(studentId) ??
              (_sessionService.identificationNo == studentId
                  ? _sessionService.user
                  : null);
          numericStudentId = studentObj?.id;
        }
      }
      numericStudentId ??= student?.id ?? _sessionService.user?.id;

      final finalStudentId =
          numericStudentId ?? studentId ?? _sessionService.identificationNo;
      final hasAuth =
          _sessionService.token != null && _sessionService.token!.isNotEmpty;

      if (!hasAuth && student == null && finalStudentId == null) {
        log('logout skipped: no active authenticated session.');
        return true;
      }

      final contact = mobileNumber ??
          student?.primaryContact ??
          _sessionService.user?.primaryContact;

      final result = await _apiClient.postJson<dynamic>(
        ApiRoutes.removeRegTokens,
        body: {
          if (finalStudentId != null) 'StudentId': finalStudentId,
          if (finalStudentId != null) 'Id': [finalStudentId],
          'Type': 'ParentSdk',
          if (fcmToken != null && fcmToken.isNotEmpty) 'DeviceId': fcmToken,
          if (contact != null) 'MobileNumber': contact,
        },
      );
      if (!result.isSuccess) {
        log(
          'logout failed [${result.statusCode}]: ${result.error?.message}',
        );
        return false;
      }
      return true;
    } on DioException catch (e) {
      log('logout network error', error: e);
      return false;
    } catch (error, stack) {
      log('logout error', error: error, stackTrace: stack);
      return false;
    }
  }

  Future<bool> removeRegTokens(String token) => logout(token: token);
}
