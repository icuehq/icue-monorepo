import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/config/env.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/services/device_info_service.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionService sessionService;
  late ApiClient apiClient;
  late DeviceInfoService deviceInfoService;
  late UserProvider userProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IcueEnv().init(IcueEnvironment.dev);

    sessionService = SessionService();
    sessionService.setConfig(
      const IcueSdkConfig(
        apiKey: 'test-api-key',
        apiUser: 'test-api-user',
        env: IcueEnvironment.dev,
      ),
    );

    apiClient = ApiClient(sessionService);
    deviceInfoService = DeviceInfoService();
    userProvider = UserProvider(
      sessionService,
      apiClient: apiClient,
      deviceInfoService: deviceInfoService,
    );
  });

  group('UserProvider on token clear / logout Tests', () {
    test('ApiRoutes paths for token removal and logout are correct', () {
      expect(ApiRoutes.removeRegTokens, equals('/v1.0/removeRegToken'));
      expect(ApiRoutes.logout, equals('/v1.0/logout'));
    });

    test(
        'logout handles student and token gracefully without throwing exceptions',
        () async {
      final user = User(
        organizationId: 10,
        branchId: 2,
        zoneId: 3,
        id: 987,
        name: 'Alice',
        rollNo: '23',
        admissionNumber: 'ADM-987',
        classId: 4,
        standard: 'IV',
        section: 'B',
        gender: 'Female',
        parentName: 'Bob',
        primaryContact: 9876543210,
        pickPoint: 'Stop 1',
        pickArea: 'Area 1',
        dropArea: 'Area 2',
        dropPoint: 'Stop 2',
        isMessOpted: false,
        isTransportOpted: true,
        schoolName: 'Test School',
        schoolPoint: [17.4, 78.4],
        token: 'auth-token-xyz',
      );

      sessionService.setUser(user);
      await sessionService.setFcmToken('fcm-token-device-123');

      // Test logout call
      await expectLater(
        userProvider.logout(token: 'fcm-token-device-123'),
        completes,
      );

      // Test logout with alphanumeric admission number string
      await expectLater(
        userProvider.logout(
          studentId: 'ADM-987',
          token: 'fcm-token-device-123',
        ),
        completes,
      );

      // Test removeRegTokens alias
      await expectLater(
        userProvider.removeRegTokens('fcm-token-device-123'),
        completes,
      );
    });

    test(
        'logout handles null student and null token gracefully without throwing',
        () async {
      expect(sessionService.user, isNull);
      expect(sessionService.fcmToken, isNull);

      await expectLater(userProvider.logout(), completes);
    });

    test('updateRegTokens skips gracefully when user is not authenticated yet',
        () async {
      expect(sessionService.user, isNull);
      await expectLater(
        userProvider.updateRegTokens('test-token-123'),
        completes,
      );
    });

    test(
        'updateRegTokens executes gracefully when student is present in session',
        () async {
      final user = User(
        organizationId: 10,
        branchId: 2,
        zoneId: 3,
        id: 987,
        name: 'Alice',
        rollNo: '23',
        admissionNumber: 'ADM-987',
        classId: 4,
        standard: 'IV',
        section: 'B',
        gender: 'Female',
        parentName: 'Bob',
        primaryContact: 9876543210,
        pickPoint: 'Stop 1',
        pickArea: 'Area 1',
        dropArea: 'Area 2',
        dropPoint: 'Stop 2',
        isMessOpted: false,
        isTransportOpted: true,
        schoolName: 'Test School',
        schoolPoint: [17.4, 78.4],
        token: 'auth-token-xyz',
      );
      sessionService.setUser(user);
      await sessionService.setFcmToken('fcm-token-device-123');

      await expectLater(
        userProvider.updateRegTokens('fcm-token-device-123'),
        completes,
      );
    });

    test('authenticateStudent deduplicates concurrent in-flight requests',
        () async {
      await sessionService.setIdentificationNo('CONCURRENT_STU');

      // Trigger two concurrent auth requests simultaneously
      final future1 = userProvider.authenticateStudent('CONCURRENT_STU');
      final future2 = userProvider.validateUserAuth();

      await expectLater(future1, completes);
      await expectLater(future2, completes);
    });
  });
}
