import 'package:flutter_test/flutter_test.dart';
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

  setUp(() async {
    await IcueSdk.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await IcueSdk.resetForTesting();
  });

  group('IcueNotifications Contract & Modes', () {
    test('Disabled mode has expected properties', () {
      const disabled = IcueNotifications.disabled();
      expect(disabled.isEnabled, isFalse);
      expect(disabled.presentation, equals(IcueNotificationPresentation.none));
      expect(disabled.inAppNotificationDuration, isNull);
      expect(disabled.autoNavigateOnTap, isFalse);
      expect(disabled.onNotificationReceived, isNull);
      expect(disabled.onNavigationIntent, isNull);
      expect(disabled.onNotificationTapped, isNull);
      expect(disabled, equals(const IcueNotifications.disabled()));
    });

    test('HostManaged mode preserves custom settings', () {
      var received = false;
      var intentHandled = false;
      var tapped = false;

      final hostManaged = IcueNotifications.hostManaged(
        token: 'host-token-xyz',
        presentation: IcueNotificationPresentation.system,
        inAppNotificationDuration: const Duration(seconds: 4),
        autoNavigateOnTap: false,
        onNotificationReceived: (_) => received = true,
        onNavigationIntent: (_) => intentHandled = true,
        onNotificationTapped: (_) => tapped = true,
      ) as IcueNotificationsHostManaged;

      expect(hostManaged.isEnabled, isTrue);
      expect(hostManaged.token, equals('host-token-xyz'));
      expect(
        hostManaged.presentation,
        equals(IcueNotificationPresentation.system),
      );
      expect(
        hostManaged.inAppNotificationDuration,
        equals(const Duration(seconds: 4)),
      );
      expect(hostManaged.autoNavigateOnTap, isFalse);

      hostManaged.onNotificationReceived?.call(const IcueNotification());
      hostManaged.onNavigationIntent?.call(
        const IcueNavigationIntent(identificationNo: '123'),
      );
      hostManaged.onNotificationTapped?.call(const IcueNotification());

      expect(received, isTrue);
      expect(intentHandled, isTrue);
      expect(tapped, isTrue);
    });

    test('FirebaseManaged mode preserves custom settings', () {
      const fbManaged = IcueNotifications.firebaseManaged(
        autoRegisterFcmBackgroundHandler: true,
        autoRequestPermission: true,
        presentation: IcueNotificationPresentation.none,
      ) as IcueNotificationsFirebaseManaged;

      expect(fbManaged.isEnabled, isTrue);
      expect(fbManaged.autoRegisterFcmBackgroundHandler, isTrue);
      expect(fbManaged.autoRequestPermission, isTrue);
      expect(fbManaged.presentation, equals(IcueNotificationPresentation.none));
      expect(fbManaged.autoNavigateOnTap, isTrue);
    });
  });

  group('IcueLaunchResult & Exceptions', () {
    test('IcueLaunchSuccess properties', () {
      const success = IcueLaunchResult.success();
      expect(success.isSuccess, isTrue);
      expect(success.isBuffered, isFalse);
      expect(success.isFailure, isFalse);
      expect(success.errorMessage, isNull);
      expect(success, equals(const IcueLaunchSuccess()));
    });

    test('IcueLaunchBuffered properties', () {
      const buffered =
          IcueLaunchResult.buffered(identificationNo: 'BUFFERED_ID')
              as IcueLaunchBuffered;
      expect(buffered.isSuccess, isFalse);
      expect(buffered.isBuffered, isTrue);
      expect(buffered.isFailure, isFalse);
      expect(buffered.errorMessage, isNull);
      expect(buffered.identificationNo, equals('BUFFERED_ID'));
      expect(
        buffered,
        equals(
          const IcueLaunchBuffered(identificationNo: 'BUFFERED_ID'),
        ),
      );
    });

    test('IcueLaunchFailure properties and exception types', () {
      const err1 = IcueNotInitializedException();
      const failure1 = IcueLaunchResult.failure(error: err1);
      expect(failure1.isSuccess, isFalse);
      expect(failure1.isBuffered, isFalse);
      expect(failure1.isFailure, isTrue);
      expect(failure1.errorMessage, contains('not initialized'));

      const err2 = IcueInvalidStudentException('Student missing');
      const failure2 = IcueLaunchResult.failure(error: err2);
      expect(failure2.errorMessage, equals('Student missing'));

      const err3 = IcueNavigationException('Context unmounted');
      const failure3 = IcueLaunchResult.failure(error: err3);
      expect(failure3.errorMessage, equals('Context unmounted'));
    });
  });

  group('IcueSetupReport Preflight Checks', () {
    test('checkSetup accurately reports missing configs and issues', () async {
      final report = await IcueSdk.checkSetup();
      expect(report.isInitialized, isFalse);
      expect(report.apiKeyConfigured, isFalse);
      expect(report.apiUserConfigured, isFalse);
      expect(report.isReady, isFalse);
      expect(report.issues.length, greaterThanOrEqualTo(2));
      expect(report.toString(), contains('IcueSetupReport'));

      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'valid-api-key',
          apiUser: 'valid-api-user',
          identificationNo: 'STU-99',
          env: IcueEnvironment.dev,
        ),
      );

      final readyReport = await IcueSdk.checkSetup(targetStudentId: 'STU-99');
      expect(readyReport.isInitialized, isTrue);
      expect(readyReport.apiKeyConfigured, isTrue);
      expect(readyReport.apiUserConfigured, isTrue);
      expect(readyReport.activeIdentificationNo, equals('STU-99'));
    });
  });

  group('IcueNotification & IcueNavigationIntent Models', () {
    test('IcueNotification copyWith and equality', () {
      const notif1 = IcueNotification(
        title: 'Title 1',
        body: 'Body 1',
        admissionNo: '101',
      );

      final notif2 = notif1.copyWith(title: 'Title 2');
      expect(notif2.title, equals('Title 2'));
      expect(notif2.body, equals('Body 1'));
      expect(notif2.admissionNo, equals('101'));

      expect(
        notif1,
        equals(
          const IcueNotification(
            title: 'Title 1',
            body: 'Body 1',
            admissionNo: '101',
          ),
        ),
      );
      expect(notif1.hashCode, isNotNull);
      expect(notif1.toString(), contains('IcueNotification'));
    });

    test('IcueNavigationIntent equality and properties', () {
      const intent1 = IcueNavigationIntent(
        identificationNo: 'STU-500',
        action: 'bus_tracking',
      );
      const intent2 = IcueNavigationIntent(
        identificationNo: 'STU-500',
        action: 'bus_tracking',
      );

      expect(intent1, equals(intent2));
      expect(intent1.hashCode, equals(intent2.hashCode));
      expect(intent1.toString(), contains('STU-500'));
    });
  });

  group('IcueSdk.notifications manager tests', () {
    test('configure updates runtime notifications', () async {
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'key',
          apiUser: 'user',
          env: IcueEnvironment.dev,
        ),
      );

      expect(IcueSdk.notifications.isConfigured, isTrue);
      expect(
        IcueSdk.notifications.currentConfig,
        equals(const IcueNotifications.disabled()),
      );

      await IcueSdk.notifications.configure(
        const IcueNotifications.hostManaged(
          token: 'token-dynamically-configured',
        ),
      );

      expect(
        IcueSdk.notifications.currentConfig,
        isA<IcueNotificationsHostManaged>(),
      );
    });

    test('permission status returns safe defaults when uninitialized',
        () async {
      expect(
        await IcueSdk.notifications.permissionStatus,
        equals(IcuePermissionStatus.notDetermined),
      );
      expect(await IcueSdk.notifications.isPermissionGranted, isFalse);
      expect(
        await IcueSdk.notifications.requestPermission(),
        equals(IcuePermissionStatus.notDetermined),
      );
    });

    test('handleMessage and handleTap route payloads safely', () async {
      IcueNotification? received;
      IcueNotification? tapped;

      final sub1 = IcueSdk.onNotificationReceived.listen((n) => received = n);
      final sub2 = IcueSdk.onNotificationTapped.listen((n) => tapped = n);

      await IcueSdk.notifications.handleMessage({
        'provider': 'icue',
        'type': 'bus_tracking',
        'AdmissionNo': 'STU-HM-1',
        'title': 'Bus nearby',
      });

      expect(received, isNotNull);
      expect(received!.admissionNo, equals('STU-HM-1'));

      await IcueSdk.notifications.handleTap({
        'provider': 'icue',
        'type': 'bus_tracking',
        'AdmissionNo': 'STU-HM-2',
        'title': 'Bus at stop',
      });

      expect(tapped, isNotNull);
      expect(tapped!.admissionNo, equals('STU-HM-2'));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('reconfiguring notifications preserves active student session',
        () async {
      await IcueSdk.init(
        const IcueSdkConfig(
          apiKey: 'key1',
          apiUser: 'user1',
          identificationNo: 'STUDENT-SESSION-1',
          env: IcueEnvironment.dev,
        ),
      );

      final session = getIt<SessionService>();
      expect(session.identificationNo, equals('STUDENT-SESSION-1'));

      // Re-init with updated notification callback closures
      await IcueSdk.init(
        IcueSdkConfig(
          apiKey: 'key1',
          apiUser: 'user1',
          env: IcueEnvironment.dev,
          notifications: IcueNotifications.hostManaged(
            onNavigationIntent: (intent) {},
          ),
        ),
      );

      // Session MUST be preserved because credentials did not change
      expect(session.identificationNo, equals('STUDENT-SESSION-1'));
    });

    test('IcueSetupReport toDiagnosticSummary formats ASCII table', () async {
      final report = await IcueSdk.checkSetup();
      final summary = report.toDiagnosticSummary();
      expect(summary, contains('iCue SDK Diagnostic Report'));
      expect(summary, contains('SDK Initialized'));
    });
  });
}
