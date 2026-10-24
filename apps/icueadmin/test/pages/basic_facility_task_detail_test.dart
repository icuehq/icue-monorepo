import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/models/app_settings.dart';
import 'package:icueadmin/models/facility_task.dart';
import 'package:icueadmin/pages/facility_management/basic_facility_task_detail_page.dart';
import 'package:icueadmin/providers/common_provider.dart';
import 'package:icueadmin/providers/facility_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';
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

  dynamic capturedData;
  String? capturedPath;
  Response? mockResponse;
  final List<Map<String, dynamic>> postCalls = [];

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    capturedPath = path;
    capturedData = data;
    postCalls.add({'path': path, 'data': data});

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

    if (path == '/v1.0/getFacilityTasksByQrCode') {
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
              'FacilityPath': 'Block 1 || First Floor || MYP Girls Washroom',
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

    if (path == '/v1.0/getCleaningTask') {
      final id = data is Map ? data['Id'] : 501;
      final isCompletedTask = id == 502;

      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'err': false,
          'message': 'Success',
          'data': {
            'Id': id,
            'ScheduleName': isCompletedTask
                ? 'Afternoon Washroom Cleaning'
                : 'Morning Washroom Cleaning',
            'Status': isCompletedTask ? 'Completed' : 'InProgress',
            'ScheduledStartTime': isCompletedTask ? '01:00 PM' : '07:00 AM',
            'ScheduledEndTime': isCompletedTask ? '02:00 PM' : '08:00 AM',
            'AssignedUser': 'Mohan Krishna',
            'ChecklistSnapshot': [],
            'ChecklistResults': [],
            'BeforePhotos': [],
            'AfterPhotos': [],
          },
        },
      );
    }

    return mockResponse ??
        Response(
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
    tempDir = await Directory.systemTemp.createTemp('basic_task_detail_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    fakeApiClient = FakeApiClient();
    facilityProvider = FacilityProvider(fakeApiClient);
    commonProvider = CommonProvider(fakeApiClient);
    commonProvider.appSettings = AppSettings(
      err: false,
      message: 'OK',
      fmsCnfg: FmsCnfg(isBasicFacilityMgmt: true, maxCleaningImages: 3),
    );
  });

  Widget createTestWidget({String? qrCode, int? taskId}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FacilityProvider>.value(value: facilityProvider),
        ChangeNotifierProvider<CommonProvider>.value(value: commonProvider),
      ],
      child: MaterialApp(
        home: BasicFacilityTaskDetailPage(qrCode: qrCode, taskId: taskId),
      ),
    );
  }

  testWidgets(
    'renders task details loaded by QR code and verifies IsBasicFacilityMgmt',
    (tester) async {
      await tester.pumpWidget(createTestWidget(qrCode: 'QR-WASH-G-01'));
      await tester.pumpAndSettle();

      // Verify IsBasicFacilityMgmt was passed to API
      final qrCall = fakeApiClient.postCalls.firstWhere(
        (c) => c['path'] == '/v1.0/getFacilityTasksByQrCode',
      );
      expect(qrCall['data']['IsBasicFacilityMgmt'], isTrue);

      // Verify startCleaningTask was called
      final startCall = fakeApiClient.postCalls.any(
        (c) => c['path'] == '/v1.0/startCleaningTask',
      );
      expect(startCall, isTrue);

      // Verify getCleaningTask was NOT called at all
      final getTaskCall = fakeApiClient.postCalls.any(
        (c) => c['path'] == '/v1.0/getCleaningTask',
      );
      expect(getTaskCall, isFalse);

      // Verify facilityPath is displayed as breadcrumbs
      expect(
        find.text('Block 1 • First Floor • MYP Girls Washroom'),
        findsAtLeastNWidgets(1),
      );

      expect(find.text('Morning Washroom Cleaning'), findsAtLeastNWidgets(1));
      expect(find.text('Shift: 07:00 AM • Mohan Krishna'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('Take Photo to Submit'), findsOneWidget);
    },
  );

  testWidgets('validates submission requires at least 1 photo', (tester) async {
    await tester.pumpWidget(createTestWidget(qrCode: 'QR-WASH-G-01'));
    await tester.pumpAndSettle();

    final submitButton = find.text('Take Photo to Submit');
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Please take at least 1 photo of the cleaned area before submitting.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders completed state when task is already completed', (
    tester,
  ) async {
    facilityProvider.cleaningTasksQr = [
      FacilityTask(
        id: 502,
        scheduleName: 'Afternoon Washroom Cleaning',
        status: 'Completed',
        facilityPath: 'Block 2 || Ground Floor || Afternoon Washroom',
        scheduledStartTime: '01:00 PM',
        scheduledEndTime: '02:00 PM',
      ),
    ];

    await tester.pumpWidget(createTestWidget(taskId: 502));
    await tester.pumpAndSettle();

    expect(find.text('Cleaning Completed Today!'), findsOneWidget);
    expect(
      find.text('Block 2 • Ground Floor • Afternoon Washroom'),
      findsOneWidget,
    );
    expect(find.text('Scan Next QR Code'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    expect(find.textContaining('Submitted Photos'), findsNothing);

    // Verify getCleaningTask was NOT called
    final getTaskCall = fakeApiClient.postCalls.any(
      (c) => c['path'] == '/v1.0/getCleaningTask',
    );
    expect(getTaskCall, isFalse);
  });
}
