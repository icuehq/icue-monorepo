import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/config/dev_config.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/config/prod_config.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';
import 'package:icueadmin/services/hrms_api_client.dart';

class FakeCrashlyticsService extends Fake implements CrashlyticsService {
  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCrashlyticsService fakeCrashlytics;

  setUp(() {
    fakeCrashlytics = FakeCrashlyticsService();
  });

  group('Configuration & Base URLs', () {
    test('DevConfig returns correct base URLs', () {
      final dev = DevConfig();
      expect(dev.baseUrl, 'https://itraxpro.com');
      expect(dev.hrmsBaseUrl, 'https://hrmscore.itraxpro.com');
      expect(dev.env, 'DEV');
    });

    test('ProdConfig returns correct base URLs', () {
      final prod = ProdConfig();
      expect(prod.baseUrl, 'https://icuepro.com');
      expect(prod.hrmsBaseUrl, 'https://hrmscore.icuepro.com');
      expect(prod.env, 'PROD');
    });
  });

  group('ApiClient and HrmsApiClient Isolation', () {
    test(
      'Both clients have independent Dio instances and respective base URLs',
      () {
        Env().config = DevConfig();
        final coreClient = ApiClient(fakeCrashlytics);
        final hrmsClient = HrmsApiClient(fakeCrashlytics);

        expect(coreClient.baseUrl, 'https://itraxpro.com/api');
        expect(hrmsClient.baseUrl, 'https://hrmscore.itraxpro.com');

        // Dio instances must be completely separate instances
        expect(identical(coreClient.dio, hrmsClient.dio), isFalse);
        expect(coreClient.dio.options.baseUrl, 'https://itraxpro.com/api');
        expect(hrmsClient.dio.options.baseUrl, 'https://hrmscore.itraxpro.com');
      },
    );

    test(
      'ApiClient includes adminapp Source and exempts driver/vehicle docs',
      () {
        final coreClient = ApiClient(fakeCrashlytics);
        final extra = coreClient.getExtraRequestData();

        expect(extra?['Source'], 'adminapp');
        expect(coreClient.errorExemptPaths, contains('getDriverDocs'));
        expect(coreClient.errorExemptPaths, contains('getVehicleDocs'));
        expect(coreClient.clientName, 'ApiClient');
      },
    );

    test(
      'HrmsApiClient has default clientName and configurable extra fields',
      () {
        final hrmsClient = HrmsApiClient(fakeCrashlytics);

        expect(hrmsClient.clientName, 'HrmsApiClient');
        expect(hrmsClient.errorExemptPaths, isEmpty);
        expect(hrmsClient.getExtraRequestData(), isNull);

        // Verify includeBranchId flag
        hrmsClient.includeBranchId = true;
        expect(hrmsClient.getExtraRequestData(), isNotNull);
      },
    );

    test('ProdConfig baseUrl propagates to both clients', () {
      Env().config = ProdConfig();
      final coreClient = ApiClient(fakeCrashlytics);
      final hrmsClient = HrmsApiClient(fakeCrashlytics);

      expect(coreClient.baseUrl, 'https://icuepro.com/api');
      expect(hrmsClient.baseUrl, 'https://hrmscore.icuepro.com');
      expect(coreClient.dio.options.baseUrl, 'https://icuepro.com/api');
      expect(hrmsClient.dio.options.baseUrl, 'https://hrmscore.icuepro.com');
    });
  });
}
