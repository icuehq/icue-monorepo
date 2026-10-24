import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/models/app_settings.dart';
import 'package:icueadmin/models/branches.dart';
import 'package:icueadmin/models/role_actions.dart';
import 'package:icueadmin/models/user_info.dart';
import 'package:icueadmin/pages/dashboard/dashboard_page.dart';
import 'package:icueadmin/providers/common_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';
import 'package:icueadmin/services/hive_service.dart';
import 'package:icueadmin/services/notification_service.dart';
import 'package:provider/provider.dart';

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

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(Dio(), FakeCrashlyticsService());

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'err': false, 'message': 'OK', 'data': {}},
    );
  }
}

class FakeNotificationService extends Fake implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<AuthorizationStatus> getPermissionStatus() async {
    return AuthorizationStatus.authorized;
  }
}

void main() {
  late Directory tempDir;
  late FakeApiClient fakeApiClient;
  late CommonProvider commonProvider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Env().initEnvConfig();
    tempDir = await Directory.systemTemp.createTemp('dashboard_facility_test');
    Hive.init(tempDir.path);

    Hive.registerAdapter(RoleActionsAdapter());
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(RoleAdapter());
    Hive.registerAdapter(BranchAdapter());

    await Hive.openBox<RoleActions>('getActionsByRole-v2');
    await Hive.openBox<UserInfo>('userInfo-v2');
    await Hive.openBox<Branch>('zonalBranch-v2');

    final getIt = GetIt.instance;
    if (getIt.isRegistered<NotificationService>()) {
      getIt.unregister<NotificationService>();
    }
    getIt.registerSingleton<NotificationService>(FakeNotificationService());
  });

  tearDownAll(() async {
    await HiveService.userInfoBox.clear();
    await HiveService.getActionsByRoleBox.clear();
    await HiveService.zonalBranch.clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    fakeApiClient = FakeApiClient();
    commonProvider = CommonProvider(fakeApiClient);

    await HiveService.userInfoBox.clear();
    await HiveService.getActionsByRoleBox.clear();
    await HiveService.zonalBranch.clear();
  });

  UserInfo createUserInfo({required String roleName, String name = 'Ramesh'}) {
    return UserInfo(
      id: 1,
      name: name,
      userName: 'ramesh',
      organizationId: 10,
      zoneId: 5,
      branchId: 101,
      roles: [Role(id: 1, name: roleName)],
      classes: [],
      mobile: '9876543210',
      sesid: 'sess123',
      isCorporate: false,
      isLogistics: false,
      orgType: 'School',
      typeOfBusiness: 'Education',
      loginType: 'staff',
      wardId: null,
      token: 'jwt_test_token',
      isFirstLogin: false,
      schoolShortName: 'ICUE',
    );
  }

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CommonProvider>.value(value: commonProvider),
      ],
      child: const MaterialApp(home: DashboardPage()),
    );
  }

  testWidgets(
    'displays Scan QR Code button and hides tiles when user is Fms_Cleaner and IsBasicFacilityMgmt is true',
    (tester) async {
      await HiveService.userInfoBox.add(
        createUserInfo(roleName: 'Fms_Cleaner'),
      );
      await HiveService.getActionsByRoleBox.add(
        RoleActions(
          id: 10,
          name: 'My Cleaning Tasks',
          routeState: 'layout.fm_mycleaningtasks',
          displayName: 'My Cleaning Tasks',
          icon: '',
          tabOrder: 1,
        ),
      );

      commonProvider.appSettings = AppSettings(
        err: false,
        message: 'OK',
        fmsCnfg: FmsCnfg(isBasicFacilityMgmt: true, maxCleaningImages: 3),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that Basic Facility Cleaner Hero is displayed
      expect(find.text('Facility Cleaning'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(
        find.text(
          'Scan the QR code at your cleaning location to begin your task.',
        ),
        findsOneWidget,
      );

      // Verify that the standard action tiles are NOT displayed
      expect(find.text('My Cleaning Tasks'), findsNothing);
    },
  );

  testWidgets(
    'displays action tiles and does NOT show Scan QR hero when IsBasicFacilityMgmt is false',
    (tester) async {
      await HiveService.userInfoBox.add(
        createUserInfo(roleName: 'Fms_Cleaner'),
      );
      await HiveService.getActionsByRoleBox.add(
        RoleActions(
          id: 10,
          name: 'My Cleaning Tasks',
          routeState: 'layout.fm_mycleaningtasks',
          displayName: 'My Cleaning Tasks',
          icon: '',
          tabOrder: 1,
        ),
      );

      commonProvider.appSettings = AppSettings(
        err: false,
        message: 'OK',
        fmsCnfg: FmsCnfg(isBasicFacilityMgmt: false, maxCleaningImages: 3),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that standard tiles are displayed
      expect(find.text('My Cleaning Tasks'), findsOneWidget);

      // Verify that the Basic Facility Cleaner Hero is NOT displayed
      expect(find.text('Scan QR Code'), findsNothing);
      expect(find.text('Facility Cleaning'), findsNothing);
    },
  );

  testWidgets(
    'displays standard action tiles when user is not Fms_Cleaner even if IsBasicFacilityMgmt is true',
    (tester) async {
      await HiveService.userInfoBox.add(
        createUserInfo(roleName: 'Fleet_Admin', name: 'Admin User'),
      );
      await HiveService.getActionsByRoleBox.add(
        RoleActions(
          id: 20,
          name: 'Track Vehicle',
          routeState: 'layout.trackvehicle',
          displayName: 'Track Vehicle',
          icon: '',
          tabOrder: 1,
        ),
      );

      commonProvider.appSettings = AppSettings(
        err: false,
        message: 'OK',
        fmsCnfg: FmsCnfg(isBasicFacilityMgmt: true, maxCleaningImages: 3),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that admin tiles are displayed
      expect(find.text('Track Vehicle'), findsOneWidget);

      // Verify that the Basic Facility Cleaner Hero is NOT displayed
      expect(find.text('Scan QR Code'), findsNothing);
      expect(find.text('Facility Cleaning'), findsNothing);
    },
  );
}
