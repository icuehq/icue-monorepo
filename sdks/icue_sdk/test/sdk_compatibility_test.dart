import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/services/injectable.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SDK Compatibility & Isolation Tests', () {
    test('SDK DI container (getIt) is isolated from GetIt.instance', () async {
      // SDK getIt has SessionService registered
      expect(getIt.isRegistered<SessionService>(), isTrue);

      // Global GetIt.instance should NOT have SessionService registered
      expect(GetIt.instance.isRegistered<SessionService>(), isFalse);

      // Registering or resetting GetIt.instance must not impact SDK getIt
      GetIt.instance.registerSingleton<String>('host_app_service');
      expect(GetIt.instance<String>(), equals('host_app_service'));
      expect(getIt.isRegistered<String>(), isFalse);

      await GetIt.instance.reset();
      expect(getIt.isRegistered<SessionService>(), isTrue);
    });

    test(
      'isIcuePayload and isIcueNotification correctly detect namespaced and legacy iCue payloads',
      () {
        final namespacedMap = {
          'provider': 'icue',
          'type': 'bus_tracking',
          'data': {'AdmissionNo': 'STU001'},
        };
        final legacyMap1 = {'AdmissionNo': 'STU001'};
        final legacyMap2 = {'RouteTrackId': '12345'};
        final genericActionMap = {'action': 'view_order', 'order_id': '999'};
        final nonIcueMap = {'custom_app_key': 'abc'};
        final emptyMap = <String, dynamic>{};

        expect(IcueSdk.isIcuePayload(namespacedMap), isTrue);
        expect(
          IcueSdk.admissionNoFromPayload(namespacedMap),
          equals('STU001'),
        );
        expect(IcueSdk.isIcuePayload(legacyMap1), isTrue);
        expect(IcueSdk.isIcuePayload(legacyMap2), isTrue);
        // Generic action without iCue provider or domain key should be FALSE
        expect(IcueSdk.isIcuePayload(genericActionMap), isFalse);
        expect(IcueSdk.isIcuePayload(nonIcueMap), isFalse);
        expect(IcueSdk.isIcuePayload(emptyMap), isFalse);
        expect(IcueSdk.isIcuePayload(null), isFalse);

        final namespacedMsg = RemoteMessage(data: namespacedMap);
        final genericActionMsg = RemoteMessage(data: genericActionMap);
        const emptyMessage = RemoteMessage();

        expect(IcueSdk.isIcueNotification(namespacedMsg), isTrue);
        expect(IcueSdk.isIcueNotification(genericActionMsg), isFalse);
        expect(IcueSdk.isIcueNotification(emptyMessage), isFalse);
      },
    );

    test('IcuePlatformCredentials converts to FirebaseOptions cleanly', () {
      const creds = IcuePlatformCredentials(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: '123456',
        projectId: 'test-project',
        iosBundleId: 'com.example.app',
      );

      final options = creds.toFirebaseOptions();
      expect(options.apiKey, equals('test-api-key'));
      expect(options.appId, equals('test-app-id'));
      expect(options.messagingSenderId, equals('123456'));
      expect(options.projectId, equals('test-project'));
      expect(options.iosBundleId, equals('com.example.app'));

      final firebaseOptions = IcueFirebaseOptions.fromCredentials(
        android: creds,
        ios: creds,
      );

      expect(firebaseOptions.android?.apiKey, equals('test-api-key'));
      expect(firebaseOptions.ios?.iosBundleId, equals('com.example.app'));
    });

    test('SessionService handles pendingIdentificationNo correctly', () {
      final session = getIt<SessionService>();
      expect(session.pendingIdentificationNo, isNull);

      session.setPendingIdentificationNo('PENDING_STU_1');
      expect(session.pendingIdentificationNo, equals('PENDING_STU_1'));

      session.clearPendingIdentificationNo();
      expect(session.pendingIdentificationNo, isNull);
    });

    test('setPushToken stores token in session globally', () async {
      final session = getIt<SessionService>();

      await IcueSdk.setPushToken('manual-push-token-12345');
      expect(session.fcmToken, equals('manual-push-token-12345'));
    });

    test('IcueSdkConfig defaults to notifications disabled', () {
      const config = IcueSdkConfig(apiKey: 'test-key', apiUser: 'test-user');

      expect(config.notifications, equals(const IcueNotifications.disabled()));
      expect(config.notifications.isEnabled, isFalse);
      expect(config.restoreSession, isFalse);
      expect(config.env, equals(IcueEnvironment.prod));

      const hostManagedConfig = IcueSdkConfig(
        apiKey: 'test-key',
        apiUser: 'test-user',
        env: IcueEnvironment.dev,
        notifications: IcueNotifications.hostManaged(
          token: 'custom-token-1',
          presentation: IcueNotificationPresentation.system,
        ),
      );
      expect(hostManagedConfig.notifications.isEnabled, isTrue);
      expect(
        hostManagedConfig.notifications.presentation,
        equals(IcueNotificationPresentation.system),
      );
    });

    test(
        'IcueSdk.init is idempotent with matching config and auto-updates with new config',
        () async {
      await IcueSdk.resetForTesting();

      const config1 = IcueSdkConfig(
        apiKey: 'key1',
        apiUser: 'user1',
        env: IcueEnvironment.dev,
      );

      await IcueSdk.init(config1);
      expect(IcueSdk.config?.apiKey, equals('key1'));

      // Calling with identical config should succeed idempotently
      await IcueSdk.init(config1);
      expect(IcueSdk.config?.apiKey, equals('key1'));

      // Calling with new config should automatically update configuration seamlessly
      const config2 = IcueSdkConfig(
        apiKey: 'key2',
        apiUser: 'user2',
      );
      await IcueSdk.init(config2);
      expect(IcueSdk.config?.apiKey, equals('key2'));
      expect(IcueSdk.config?.apiUser, equals('user2'));
      expect(IcueSdk.config?.env, equals(IcueEnvironment.prod));

      await IcueSdk.resetForTesting();
    });

    test('concurrent matching init calls share the same initialization',
        () async {
      await IcueSdk.resetForTesting();

      const config = IcueSdkConfig(
        apiKey: 'concurrent-key',
        apiUser: 'concurrent-user',
        env: IcueEnvironment.dev,
      );

      await Future.wait([IcueSdk.init(config), IcueSdk.init(config)]);

      expect(IcueSdk.config?.apiKey, equals('concurrent-key'));
      await IcueSdk.resetForTesting();
    });

    test('logout unregisters the push token and clears the session', () async {
      await IcueSdk.resetForTesting();
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'logout-key',
          apiUser: 'logout-user',
          env: IcueEnvironment.dev,
        ),
      );

      final session = getIt<SessionService>();
      await session.setIdentificationNo('logout-student');
      await IcueSdk.setPushToken('logout-device-token');

      await IcueSdk.logout();

      expect(session.identificationNo, isNull);
      expect(IcueSdk.isInitialized, isFalse);

      await IcueSdk.resetForTesting();
    });

    test('reconfigure dynamically updates SDK configuration and clears session',
        () async {
      await IcueSdk.resetForTesting();
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'school-1-key',
          apiUser: 'school-1-user',
        ),
      );

      final session = getIt<SessionService>();
      await session.setIdentificationNo('student-1');
      expect(IcueSdk.config?.apiKey, equals('school-1-key'));
      expect(session.identificationNo, equals('student-1'));

      // Reconfigure for school 2
      await IcueSdk.reconfigure(
        const IcueSdkConfig(
          apiKey: 'school-2-key',
          apiUser: 'school-2-user',
          env: IcueEnvironment.dev,
        ),
      );

      expect(IcueSdk.config?.apiKey, equals('school-2-key'));
      expect(IcueSdk.config?.apiUser, equals('school-2-user'));
      expect(IcueSdk.config?.env, equals(IcueEnvironment.dev));
      expect(session.apiKey, equals('school-2-key'));
      expect(session.apiUser, equals('school-2-user'));
      expect(session.identificationNo, isNull);

      await IcueSdk.resetForTesting();
    });

    test(
        'IcueSdk.init accepts identificationNo in config and initializes session',
        () async {
      await IcueSdk.resetForTesting();
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'school-config-key',
          apiUser: 'school-config-user',
          identificationNo: 'student-init-123',
          env: IcueEnvironment.dev,
        ),
      );

      final session = getIt<SessionService>();
      expect(IcueSdk.config?.identificationNo, equals('student-init-123'));
      expect(session.identificationNo, equals('student-init-123'));

      await IcueSdk.resetForTesting();
    });

    test(
        'IcueSdk.init does NOT restore student session when restoreSession is false',
        () async {
      await IcueSdk.resetForTesting();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'icue_cold-start-user_active_id',
        'persisted-student-999',
      );

      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'cold-start-key',
          apiUser: 'cold-start-user',
          env: IcueEnvironment.dev,
        ),
      );

      final session = getIt<SessionService>();
      expect(session.identificationNo, isNull);

      await IcueSdk.resetForTesting();
    });

    test('IcueSdk.init restores student session when restoreSession is true',
        () async {
      await IcueSdk.resetForTesting();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'icue_cold-start-user_active_id',
        'persisted-student-999',
      );

      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'cold-start-key',
          apiUser: 'cold-start-user',
          restoreSession: true,
          env: IcueEnvironment.dev,
        ),
      );

      final session = getIt<SessionService>();
      expect(session.identificationNo, equals('persisted-student-999'));

      await IcueSdk.resetForTesting();
    });

    test(
        'isInitialized accurately reflects initialization state across lifecycle',
        () async {
      await IcueSdk.resetForTesting();
      expect(IcueSdk.isInitialized, isFalse);

      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'test-key',
          apiUser: 'test-user',
          env: IcueEnvironment.dev,
        ),
      );
      expect(IcueSdk.isInitialized, isTrue);

      await IcueSdk.logout();
      expect(IcueSdk.isInitialized, isFalse);
    });

    test('openLiveTrackingFromRoot returns typed IcueLaunchResult', () async {
      await IcueSdk.resetForTesting();
      expect(IcueSdk.isInitialized, isFalse);

      // 1. Without init: buffers the request until the SDK is initialized
      final resultUninit = await IcueSdk.openLiveTrackingFromRoot(
        identificationNo: 'DEMAND_STU_1',
      );
      expect(resultUninit.isBuffered, isTrue);
      expect(
        getIt<SessionService>().pendingIdentificationNo,
        equals('DEMAND_STU_1'),
      );

      // 2. With config: initializes and buffers if navigator is not mounted
      final resultWithConfig = await IcueSdk.openLiveTrackingFromRoot(
        identificationNo: 'DEMAND_STU_1',
        config: const IcueSdkConfig(
          apiKey: 'demand-key',
          apiUser: 'demand-user',
          env: IcueEnvironment.dev,
        ),
      );

      expect(IcueSdk.isInitialized, isTrue);
      expect(resultWithConfig.isBuffered, isTrue);
      final session = getIt<SessionService>();
      expect(session.pendingIdentificationNo, equals('DEMAND_STU_1'));

      // 3. With empty student ID: returns failure with IcueInvalidStudentException
      final resultEmptyId = await IcueSdk.openLiveTrackingFromRoot(
        identificationNo: '  ',
      );
      expect(resultEmptyId.isFailure, isTrue);
      expect(resultEmptyId.errorMessage, contains('empty'));

      await IcueSdk.resetForTesting();
    });

    test('IcueSdk.checkSetup returns actionable diagnostic report', () async {
      await IcueSdk.resetForTesting();

      final reportUninit = await IcueSdk.checkSetup();
      expect(reportUninit.isInitialized, isFalse);
      expect(reportUninit.apiKeyConfigured, isFalse);
      expect(reportUninit.issues.isNotEmpty, isTrue);

      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'setup-key',
          apiUser: 'setup-user',
          identificationNo: 'STU-001',
          env: IcueEnvironment.dev,
        ),
      );

      final reportInit = await IcueSdk.checkSetup();
      expect(reportInit.isInitialized, isTrue);
      expect(reportInit.apiKeyConfigured, isTrue);
      expect(reportInit.apiUserConfigured, isTrue);
      expect(reportInit.activeIdentificationNo, equals('STU-001'));
      expect(reportInit.notificationMode, equals('disabled'));

      await IcueSdk.resetForTesting();
    });

    test('multi-student notification registration tracks students in session',
        () async {
      await IcueSdk.resetForTesting();
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'multi-key',
          apiUser: 'multi-user',
          env: IcueEnvironment.dev,
          notifications: IcueNotifications.hostManaged(token: 'default-token'),
        ),
      );

      final session = getIt<SessionService>();
      await session.addRegisteredStudent('CHILD_1');
      await session.addRegisteredStudent('CHILD_2');

      final students = await session.getRegisteredStudents();
      expect(students, containsAll(['CHILD_1', 'CHILD_2']));

      await session.removeRegisteredStudent('CHILD_1');
      final updatedStudents = await session.getRegisteredStudents();
      expect(updatedStudents, equals(['CHILD_2']));

      await session.clearRegisteredStudents();
      final clearedStudents = await session.getRegisteredStudents();
      expect(clearedStudents, isEmpty);

      await IcueSdk.resetForTesting();
    });

    test('init -> logout -> init completes successfully and initializes SDK',
        () async {
      await IcueSdk.resetForTesting();
      expect(IcueSdk.isInitialized, isFalse);

      const config1 = IcueSdkConfig(
        apiKey: 'key1',
        apiUser: 'user1',
      );

      // 1. Initial init
      await IcueSdk.init(config1);
      expect(IcueSdk.isInitialized, isTrue);

      // 2. Logout
      await IcueSdk.logout();
      expect(IcueSdk.isInitialized, isFalse);

      // 3. Second init (Re-login)
      const config2 = IcueSdkConfig(
        apiKey: 'key2',
        apiUser: 'user2',
      );
      await IcueSdk.init(config2);
      expect(IcueSdk.isInitialized, isTrue);
      expect(IcueSdk.config?.apiKey, equals('key2'));
      expect(IcueSdk.config?.apiUser, equals('user2'));

      await IcueSdk.resetForTesting();
    });

    test(
        'reconfigure clears previous school session persistence before applying new school',
        () async {
      await IcueSdk.resetForTesting();
      final prefs = await SharedPreferences.getInstance();

      // Init School A
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'school-A-key',
          apiUser: 'school_A',
          identificationNo: 'student_A',
        ),
      );

      // Verify School A persistence
      expect(prefs.getString('icue_school_A_active_id'), equals('student_A'));

      // Reconfigure to School B
      await IcueSdk.reconfigure(
        const IcueSdkConfig(
          apiKey: 'school-B-key',
          apiUser: 'school_B',
          identificationNo: 'student_B',
        ),
      );

      // Verify School A persistence was cleared, and School B is set
      expect(prefs.containsKey('icue_school_A_active_id'), isFalse);
      expect(prefs.getString('icue_school_B_active_id'), equals('student_B'));

      await IcueSdk.resetForTesting();
    });

    test('pre-init event stream subscriptions receive post-init events',
        () async {
      await IcueSdk.resetForTesting();

      final receivedEvents = <IcueNotification>[];
      final intentEvents = <IcueNavigationIntent>[];

      // Subscribe BEFORE init is called
      final sub1 = IcueSdk.onNotificationReceived.listen(receivedEvents.add);
      final sub2 = IcueSdk.onNavigationIntent.listen(intentEvents.add);

      // Initialize SDK
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'stream-key',
          apiUser: 'stream-user',
          notifications: IcueNotifications.hostManaged(
            presentation: IcueNotificationPresentation.none,
          ),
        ),
      );

      // Send raw payload
      await IcueSdk.notifications.handleRawPayload(
        {
          'provider': 'icue',
          'type': 'bus_tracking',
          'AdmissionNo': 'STREAM_STU_1',
          'title': 'Bus Arriving',
          'body': 'Bus is near',
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(intentEvents.length, equals(1));
      expect(intentEvents.first.identificationNo, equals('STREAM_STU_1'));

      await sub1.cancel();
      await sub2.cancel();
      await IcueSdk.resetForTesting();
    });

    test('callback-only changes in IcueSdk.init update active configuration',
        () async {
      await IcueSdk.resetForTesting();

      var firstCallbackCalled = false;
      var secondCallbackCalled = false;

      final config1 = IcueSdkConfig(
        apiKey: 'cb-key',
        apiUser: 'cb-user',
        notifications: IcueNotifications.hostManaged(
          onNotificationReceived: (_) => firstCallbackCalled = true,
        ),
      );

      await IcueSdk.init(config1);

      // Call init again with updated callback
      final config2 = IcueSdkConfig(
        apiKey: 'cb-key',
        apiUser: 'cb-user',
        notifications: IcueNotifications.hostManaged(
          onNotificationReceived: (_) => secondCallbackCalled = true,
        ),
      );

      await IcueSdk.init(config2);

      // Emit notification
      await IcueSdk.notifications.handleRawPayload(
        {
          'provider': 'icue',
          'type': 'bus_tracking',
          'AdmissionNo': 'CB_STU',
          'title': 'Callback test',
        },
        isTap: false,
      );

      expect(firstCallbackCalled, isFalse);
      expect(secondCallbackCalled, isTrue);

      await IcueSdk.resetForTesting();
    });

    test('setPushToken and setIdentificationNo are safe before IcueSdk.init',
        () async {
      await IcueSdk.resetForTesting();
      expect(IcueSdk.isInitialized, isFalse);

      await IcueSdk.setPushToken('early-push-token');
      final session = getIt<SessionService>();
      expect(session.fcmToken, equals('early-push-token'));

      await IcueSdk.setIdentificationNo('early-student-id');
      expect(session.identificationNo, equals('early-student-id'));

      await IcueSdk.resetForTesting();
    });

    test('deletePushToken and logout are safe when uninitialized', () async {
      await IcueSdk.resetForTesting();
      expect(IcueSdk.isInitialized, isFalse);

      // Should complete normally without throwing
      await expectLater(IcueSdk.deletePushToken(), completes);
      await expectLater(IcueSdk.logout(), completes);
    });
  });
}
