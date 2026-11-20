import 'package:api_client/api_client.dart';
import 'package:auth/src/models/parent_user.dart';
import 'package:auth/src/services/parent_device_info.dart';
import 'package:injectable/injectable.dart';

enum ParentOtpResult { sent, notRegistered }

/// Parent login endpoints (`/v1.0/generateOtp`, `/parentLogin`, `/logout`,
/// `/updateRegTokens`, `/getStudentsList`).
@lazySingleton
class ParentAuthService {
  const ParentAuthService(this._apiClient, this._deviceInfo);

  final ApiClient _apiClient;
  final ParentDeviceInfo _deviceInfo;

  static final _noAuth = Options(extra: <String, dynamic>{'no_auth': true});

  /// Sends the login OTP. Server answers 204 when the number is not registered.
  Future<({ParentOtpResult result, String? message})> generateOtp(
    String mobile,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/generateOtp',
      data: <String, dynamic>{'username': mobile},
      options: _noAuth,
    );
    if (response.statusCode == 204) {
      return (result: ParentOtpResult.notRegistered, message: null);
    }
    final data = response.data;
    return (
      result: ParentOtpResult.sent,
      message: data is Map<String, dynamic> ? data['message'] as String? : null,
    );
  }

  Future<ParentUser> login(String mobile, String otp) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/parentLogin',
      data: <String, dynamic>{
        'username': mobile,
        'password': otp,
        ..._deviceInfo.json,
      },
      options: _noAuth,
    );
    return ParentUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// Refreshes the student list and token.
  Future<ParentUser> getStudentsList({
    required String mobile,
    required int? studentId,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStudentsList',
      data: <String, dynamic>{
        'Mobile': mobile,
        'StudentId': studentId,
        ..._deviceInfo.json,
      },
    );
    return ParentUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateRegistrationToken({
    required String deviceToken,
    required List<int> studentIds,
    required int? studentId,
  }) => _apiClient.post<dynamic>(
    '/v1.0/updateRegTokens',
    data: <String, dynamic>{
      'DeviceId': deviceToken,
      'Type': 'Parent',
      'Id': studentIds,
      'StudentId': studentId,
    },
  );

  Future<void> logout({
    required int? studentId,
    required String? deviceToken,
    required String? mobile,
  }) => _apiClient.post<dynamic>(
    '/v1.0/logout',
    data: <String, dynamic>{
      'StudentId': studentId,
      'Type': 'Parent',
      'DeviceId': deviceToken,
      'MobileNumber': mobile,
    },
  );
}
