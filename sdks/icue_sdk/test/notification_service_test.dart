import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';
import 'package:icue_sdk/src/services/device_info_service.dart';
import 'package:icue_sdk/src/services/injectable.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:icue_sdk/src/services/notification_service.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:icue_sdk/src/widgets/in_app_notification_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  group('Notification & Payload Filtering Tests', () {
    test(
        'isIcuePayload accepts valid namespaced payloads and rejects foreign ones',
        () {
      final validIcueTracking = {
        'provider': 'icue',
        'type': 'bus_tracking',
        'AdmissionNo': 'STU1001',
      };
      final validIcueNotification = {
        'provider': 'icue',
        'type': 'icue_notification',
        'AdmissionNo': 'STU1002',
      };
      final legacyTracking = {
        'AdmissionNo': 'STU1003',
        'RouteTrackId': '888',
      };
      final hostAppOrderNotification = {
        'provider': 'ecommerce_host',
        'type': 'order_shipped',
        'action': 'view_order',
        'order_id': 'ORD-999',
      };
      final hostAppGenericAction = {
        'action': 'open_chat',
        'chat_id': 'c123',
      };

      expect(IcueSdk.isIcuePayload(validIcueTracking), isTrue);
      expect(IcueSdk.isIcuePayload(validIcueNotification), isTrue);
      expect(IcueSdk.isIcuePayload(legacyTracking), isTrue);

      // Foreign host-app notifications MUST NOT be identified as iCue payloads
      expect(IcueSdk.isIcuePayload(hostAppOrderNotification), isFalse);
      expect(IcueSdk.isIcuePayload(hostAppGenericAction), isFalse);
      expect(IcueSdk.isIcuePayload(null), isFalse);
      expect(IcueSdk.isIcuePayload({}), isFalse);
    });

    test('IcueNotification models parse correctly and serialize to maps', () {
      final payload = {
        'provider': 'icue',
        'type': 'bus_tracking',
        'AdmissionNo': 'STU_PARSE_1',
        'action': 'live_tracking',
        'title': 'School Bus Arrived',
        'body': 'Bus is approaching your stop',
        'messageId': 'msg-12345',
        'sentTime': 1700000000000,
      };

      final notif = IcueNotification.fromMap(payload);
      expect(notif.admissionNo, equals('STU_PARSE_1'));
      expect(notif.action, equals('live_tracking'));
      expect(notif.title, equals('School Bus Arrived'));
      expect(notif.body, equals('Bus is approaching your stop'));
      expect(notif.messageId, equals('msg-12345'));
      expect(notif.sentTime, isNotNull);

      final map = notif.toMap();
      expect(map['AdmissionNo'], equals('STU_PARSE_1'));
      expect(map['title'], equals('School Bus Arrived'));
    });

    test('IcueNotification correctly parses production route started response',
        () {
      final productionResponse = {
        'icon': 'ic_launcher',
        'action': 'Track',
        'Sound': 'default',
        'body': 'Dear Parent, R - 02 Pickup has been started.',
        'title': 'Naveen Aluri - Route has been started',
        'click_action': '0',
        'StudentName': 'Naveen Aluri',
        'AdmissionNo': '7978',
        'StudentId': '108233',
      };

      expect(IcueSdk.isIcuePayload(productionResponse), isTrue);

      final notif = IcueNotification.fromMap(productionResponse);
      expect(notif.admissionNo, equals('7978'));
      expect(notif.action, equals('Track'));
      expect(notif.title, equals('Naveen Aluri - Route has been started'));
      expect(
        notif.body,
        equals('Dear Parent, R - 02 Pickup has been started.'),
      );
      expect(notif.data['StudentName'], equals('Naveen Aluri'));
      expect(notif.data['StudentId'], equals('108233'));
      expect(notif.data['Sound'], equals('default'));
      expect(notif.data['icon'], equals('ic_launcher'));
    });

    test(
        'IcueSdk notification streams broadcast typed received, intent, and tap events',
        () async {
      IcueNotification? receivedMsg;
      IcueNavigationIntent? intentReceived;
      IcueNotification? tappedData;

      final sub1 = IcueSdk.onNotificationReceived.listen((msg) {
        receivedMsg = msg;
      });

      final sub2 = IcueSdk.onNavigationIntent.listen((intent) {
        intentReceived = intent;
      });

      final sub3 = IcueSdk.onNotificationTapped.listen((data) {
        tappedData = data;
      });

      final testNotif = IcueNotification.fromMap(const {
        'provider': 'icue',
        'type': 'bus_tracking',
        'AdmissionNo': '123',
        'title': 'Bus Update',
        'body': 'On time',
      });

      IcueSdk.notifyNotificationReceived(testNotif);
      IcueSdk.notifyNotificationTapped(testNotif);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedMsg, isNotNull);
      expect(receivedMsg?.admissionNo, equals('123'));
      expect(intentReceived, isNotNull);
      expect(intentReceived?.identificationNo, equals('123'));
      expect(tappedData, isNotNull);
      expect(tappedData?.admissionNo, equals('123'));

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    testWidgets(
        'IcueNotificationOverlay shows and dismisses banner on active navigator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: IcueSdk.navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Test Banner Title'), findsNothing);

      var tapped = false;

      IcueNotificationOverlay.show(
        overlayState: IcueSdk.overlayState,
        title: 'Test Banner Title',
        body: 'Test Banner Body',
        onTap: () {
          tapped = true;
        },
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Test Banner Title'), findsOneWidget);
      expect(find.text('Test Banner Body'), findsOneWidget);

      await tester.tap(find.text('Test Banner Title'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
        'IcueNotificationOverlay stays visible and dismisses on close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: IcueSdk.navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );

      IcueNotificationOverlay.show(
        overlayState: IcueSdk.overlayState,
        title: 'Persistent Title',
        body: 'Persistent Body',
        onTap: () {},
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Remains visible even after several seconds
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Persistent Title'), findsOneWidget);

      // Tap close button (Icons.close)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Persistent Title'), findsNothing);
    });

    test(
        'permission helpers return safe defaults when Firebase app is not initialized',
        () async {
      final session = SessionService();
      final apiClient = ApiClient(session);
      final deviceInfo = DeviceInfoService();
      final userProvider = UserProvider(
        session,
        apiClient: apiClient,
        deviceInfoService: deviceInfo,
      );
      final vehicleProvider = VehicleProvider(
        apiClient: apiClient,
        deviceInfoService: deviceInfo,
      );
      final notificationService = NotificationService(
        userProvider: userProvider,
        vehicleProvider: vehicleProvider,
        sessionService: session,
      );

      expect(
        await notificationService.getPermissionStatus(),
        equals(IcuePermissionStatus.notDetermined),
      );
      expect(
        await notificationService.isPermissionGranted(),
        isFalse,
      );
      expect(
        await notificationService.isNotificationPermissionEnabled(),
        isFalse,
      );
      await notificationService.dispose();
    });

    test('isIcuePayload and IcueNotification handle varied key namings', () {
      final payloadCamel = {'admissionNo': 'CAMEL1', 'title': 'Camel Case'};
      final payloadSnake = {'admission_no': 'SNAKE1', 'title': 'Snake Case'};
      final payloadStudentId = {'StudentId': 'STU_ID_1', 'title': 'Student ID'};

      expect(IcueSdk.isIcuePayload(payloadCamel), isTrue);
      expect(IcueSdk.isIcuePayload(payloadSnake), isTrue);
      expect(IcueSdk.isIcuePayload(payloadStudentId), isTrue);

      expect(
        IcueNotification.fromMap(payloadCamel).admissionNo,
        equals('CAMEL1'),
      );
      expect(
        IcueNotification.fromMap(payloadSnake).admissionNo,
        equals('SNAKE1'),
      );
      expect(
        IcueNotification.fromMap(payloadStudentId).admissionNo,
        equals('STU_ID_1'),
      );
    });

    test('openLiveTrackingFromRoot buffers when SDK is not initialized',
        () async {
      await IcueSdk.resetForTesting();

      final result = await IcueSdk.openLiveTrackingFromRoot(
        identificationNo: 'BUFFER_TEST_100',
      );

      expect(result.isBuffered, isTrue);
      expect(
        (result as IcueLaunchBuffered).identificationNo,
        equals('BUFFER_TEST_100'),
      );
      expect(
        getIt<SessionService>().pendingIdentificationNo,
        equals('BUFFER_TEST_100'),
      );
    });
  });
}
