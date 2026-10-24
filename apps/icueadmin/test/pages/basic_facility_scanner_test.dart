import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/models/app_settings.dart';
import 'package:icueadmin/models/user_info.dart';
import 'package:icueadmin/pages/facility_management/facility_qr_scanner_page.dart';
import 'package:icueadmin/providers/common_provider.dart';
import 'package:icueadmin/providers/facility_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';
import 'package:icueadmin/services/hive_service.dart';
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

  final List<Map<String, dynamic>> postCalls = [];
  bool returnEmptyTasks = false;
  bool returnError = false;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    postCalls.add({'path': path, 'data': data});

    if (path == '/v1.0/getFacilityTasksByQrCode') {
      if (returnError) {
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 400,
          data: {'err': true, 'message': 'Invalid QR Code scanned'},
        );
      }

      if (returnEmptyTasks) {
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'err': false,
            'message': 'Success',
            'data': {
              'facility': {'Id': 101, 'Name': 'Washroom'},
              'tasks': [],
            },
          },
        );
      }

      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'err': false,
          'message': 'Success',
          'data': {
            'facility': {
              'Id': 101,
              'Name': 'MYP Girls Washroom',
              'Code': 'WASH-G-01',
              'QrCode': 'QR-WASH-G-01',
            },
            'tasks': [
              {
                'Id': 501,
                'ScheduleName': 'Morning Washroom Cleaning',
                'Status': 'Pending',
                'ScheduledStartTime': '07:00 AM',
                'ScheduledEndTime': '08:00 AM',
                'AssignedUser': 'Mohan Krishna',
              },
            ],
          },
        },
      );
    }

    if (path == '/v1.0/startCleaningTask') {
      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'err': false,
          'message': 'Cleaning task started successfully',
          'data': {},
        },
      );
    }

    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'err': false, 'data': {}},
    );
  }
}

void main() {
  late Directory tempDir;
  late FakeApiClient fakeApiClient;
  late FacilityProvider facilityProvider;
  late CommonProvider commonProvider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Env().initEnvConfig();
    tempDir = await Directory.systemTemp.createTemp('basic_scanner_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(RoleAdapter());
    await Hive.openBox<UserInfo>('userInfo-v2');
  });

  tearDownAll(() async {
    await HiveService.userInfoBox.clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    fakeApiClient = FakeApiClient();
    facilityProvider = FacilityProvider(fakeApiClient);
    commonProvider = CommonProvider(fakeApiClient);
    commonProvider.appSettings = AppSettings(
      err: false,
      message: 'OK',
      fmsCnfg: FmsCnfg(
        isBasicFacilityMgmt: true,
        maxCleaningImages: 3,
      ),
    );

    await HiveService.userInfoBox.clear();
    await HiveService.userInfoBox.add(
      UserInfo(
        id: 1,
        name: 'Mohan Krishna',
        userName: 'mohan',
        organizationId: 10,
        zoneId: 5,
        branchId: 101,
        roles: [Role(id: 1, name: 'Fms_Cleaner')],
        classes: [],
        mobile: '9876543210',
        sesid: 'sess123',
        isCorporate: false,
        isLogistics: false,
        orgType: 'School',
        typeOfBusiness: 'Education',
        loginType: 'staff',
        wardId: null,
        token: 'jwt_token',
        isFirstLogin: false,
        schoolShortName: 'ICUE',
      ),
    );
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FacilityProvider>.value(value: facilityProvider),
        ChangeNotifierProvider<CommonProvider>.value(value: commonProvider),
      ],
      child: const MaterialApp(
        home: FacilityQrScannerPage(isBasic: true),
      ),
    );
  }

  testWidgets(
    'basic scanner calls getFacilityTasksByQrCode with IsBasicFacilityMgmt: true and immediately calls startCleaningTask',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Open manual entry sheet
      final manualBtn = find.text('Enter Code');
      expect(manualBtn, findsOneWidget);
      await tester.tap(manualBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enter code and submit
      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'QR-WASH-G-01');

      final findTasksBtn = find.text('Find Tasks');
      await tester.tap(findTasksBtn);
      await tester.pump();

      // Verify the loading overlay appears with step indicators
      expect(find.text('Cleaning Task Ready!'), findsOneWidget);
      expect(find.text('Verifying Schedule'), findsOneWidget);
      expect(find.text('Starting Cleaning Task'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify API calls
      final qrCall = fakeApiClient.postCalls.firstWhere(
        (c) => c['path'] == '/v1.0/getFacilityTasksByQrCode',
      );
      expect(qrCall['data']['IsBasicFacilityMgmt'], isTrue);
      expect(qrCall['data']['QrCode'], 'QR-WASH-G-01');

      final startCall = fakeApiClient.postCalls.firstWhere(
        (c) => c['path'] == '/v1.0/startCleaningTask',
      );
      expect(startCall['data']['Id'], 501);
    },
  );

  testWidgets(
    'displays error UI when no cleaning tasks are found for QR code',
    (tester) async {
      fakeApiClient.returnEmptyTasks = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Open manual entry sheet and submit
      await tester.tap(find.text('Enter Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), 'EMPTY-CODE');
      await tester.tap(find.text('Find Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify error state in overlay
      expect(find.text('Task Setup Issue'), findsOneWidget);
      expect(
        find.text('No cleaning tasks scheduled for this location today.'),
        findsOneWidget,
      );
      expect(find.text('Scan Again'), findsOneWidget);
    },
  );

  testWidgets(
    'displays error UI when getFacilityTasksByQrCode API fails',
    (tester) async {
      fakeApiClient.returnError = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), 'BAD-CODE');
      await tester.tap(find.text('Find Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify error state in overlay
      expect(find.text('Task Setup Issue'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}
