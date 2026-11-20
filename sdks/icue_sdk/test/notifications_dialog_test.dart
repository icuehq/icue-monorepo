import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/src/dialogs/notifications_dialog.dart';
import 'package:icue_sdk/src/models/route_notifications.dart';
import 'package:icue_sdk/src/providers/notifications_provider.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/services/device_info_service.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationsDialog Tests', () {
    late SessionService sessionService;
    late ApiClient apiClient;
    late DeviceInfoService deviceInfoService;
    late UserProvider userProvider;
    late NotificationsProvider notificationsProvider;

    setUp(() {
      sessionService = SessionService();
      apiClient = ApiClient(sessionService);
      deviceInfoService = DeviceInfoService();
      userProvider = UserProvider(
        sessionService,
        apiClient: apiClient,
        deviceInfoService: deviceInfoService,
      );
      notificationsProvider = NotificationsProvider(apiClient);
    });

    testWidgets(
      'NotificationsDialog renders properly in showDialog with MultiProvider without ProviderNotFoundException',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<UserProvider>.value(
                  value: userProvider,
                ),
                ChangeNotifierProvider<NotificationsProvider>.value(
                  value: notificationsProvider,
                ),
              ],
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => MultiProvider(
                            providers: [
                              ChangeNotifierProvider<
                                  NotificationsProvider>.value(
                                value: context.read<NotificationsProvider>(),
                              ),
                              ChangeNotifierProvider<UserProvider>.value(
                                value: context.read<UserProvider>(),
                              ),
                            ],
                            child: const NotificationsDialog(
                              routeTrackId: 101,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Notifications'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap to open notifications dialog
        await tester.tap(find.text('Open Notifications'));
        await tester.pump();

        // Dialog should be visible
        expect(find.text('Notifications History'), findsOneWidget);
        expect(find.text('No notifications available.'), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationsDialog renders notification timeline items when messages exist',
      (tester) async {
        notificationsProvider.msgs = [
          Msg(
            msg: 'Bus has arrived at your stop',
            at: '08:30 AM',
          ),
          Msg(
            msg: 'Bus departed from school',
            at: '08:00 AM',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<UserProvider>.value(
                  value: userProvider,
                ),
                ChangeNotifierProvider<NotificationsProvider>.value(
                  value: notificationsProvider,
                ),
              ],
              child: const NotificationsDialog(routeTrackId: 101),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Notifications History'), findsOneWidget);
        expect(find.text('Bus has arrived at your stop'), findsOneWidget);
        expect(find.text('08:30 AM'), findsOneWidget);
        expect(find.text('Bus departed from school'), findsOneWidget);
        expect(find.text('08:00 AM'), findsOneWidget);
      },
    );
  });
}
