import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../config/env.dart';
import 'base_api_client.dart';
import 'crashlytics_service.dart';

/// API Client dedicated to the HRMS Core backend services (e.g. https://hrmscore.itraxpro.com).
/// Extends [BaseApiClient] to inherit centralized error handling, authentication headers,
/// Crashlytics telemetry, and independent Dio instance isolation.
@lazySingleton
class HrmsApiClient extends BaseApiClient {
  HrmsApiClient(CrashlyticsService crashlytics)
    : super(crashlytics: crashlytics);

  HrmsApiClient.withDio(CrashlyticsService crashlytics, Dio dio)
    : super(crashlytics: crashlytics, dio: dio);

  @override
  String get baseUrl => Env().config.hrmsBaseUrl;

  @override
  String get clientName => 'HrmsApiClient';

  /// Whether to include BranchId in non-GET request bodies.
  /// Defaults to false, but can be enabled if needed.
  bool includeBranchId = false;

  @override
  Map<String, dynamic>? getExtraRequestData() {
    if (!includeBranchId) return null;
    return {'BranchId': currentBranchId};
  }
}
