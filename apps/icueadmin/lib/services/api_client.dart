import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../config/env.dart';
import 'base_api_client.dart';
import 'crashlytics_service.dart';

const _sourceKey = 'Source';
const _branchKey = 'BranchId';
const _sourceValue = 'adminapp';

/// Main API Client for the primary iCue backend.
/// Extends [BaseApiClient] with core endpoint base URL, Source/BranchId payload injection,
/// and document download error exemptions.
@lazySingleton
class ApiClient extends BaseApiClient {
  ApiClient(CrashlyticsService crashlytics) : super(crashlytics: crashlytics);

  ApiClient.withDio(CrashlyticsService crashlytics, Dio dio)
    : super(crashlytics: crashlytics, dio: dio);

  @override
  String get baseUrl => '${Env().config.baseUrl}/api';

  @override
  String get clientName => 'ApiClient';

  @override
  Map<String, dynamic>? getExtraRequestData() => {
    _sourceKey: _sourceValue,
    _branchKey: currentBranchId,
  };

  @override
  List<String> get errorExemptPaths => const [
    'getDriverDocs',
    'getVehicleDocs',
  ];
}
