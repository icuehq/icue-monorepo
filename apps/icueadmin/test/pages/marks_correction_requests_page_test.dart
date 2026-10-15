import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/marks_correction.dart';
import 'package:icueadmin/pages/exams/marks_correction_requests_page.dart';
import 'package:icueadmin/providers/exam_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/utils/navigation/app_router.dart';
import 'package:provider/provider.dart';

class MockApiClient extends Fake implements ApiClient {
  String? lastPostPath;
  dynamic lastPostData;
  dynamic nextResponseData;
  final Map<String, dynamic> responsesByPath = {};
  int nextStatusCode = 200;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    final res =
        responsesByPath[path] ??
        nextResponseData ??
        {'err': false, 'data': [], 'message': 'success'};
    return Response(
      requestOptions: RequestOptions(path: path),
      data: res,
      statusCode: nextStatusCode,
    );
  }

  @override
  void logCrash(
    String from,
    Object error,
    StackTrace? stack, {
    bool fatal = true,
    String? message,
  }) {}
}

void main() {
  late MockApiClient mockApiClient;
  late ExamProvider examProvider;

  setUp(() {
    mockApiClient = MockApiClient();
    examProvider = ExamProvider(mockApiClient);
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExamProvider>.value(value: examProvider),
      ],
      child: MaterialApp(navigatorKey: navigatorKey, home: child),
    );
  }

  final sampleRequests = [
    MarksCorrectionItem(
      examId: 30,
      studentId: 41292,
      studentName: 'Sree V',
      rollNo: '123123',
      admissionNumber: '123123',
      section: 'A',
      standard: 'Standard 10',
      examName: 'Assignment Test - 1',
      subject: 'Telugu',
      maximumMarks: 50,
      passingMarks: 35,
      currentMarks: 35,
      currentStatus: 'PRESENT',
      correction: Correction(
        status: 'Pending',
        marks: 40,
        markStatus: 'PRESENT',
        reason: 'Re-evaluation of question 4',
        requestedBy: 'sbranch',
        requestedDate: DateTime.parse('2026-09-12T06:13:10.716Z'),
      ),
      history: [
        History(
          oldMarks: 35,
          oldStatus: 'PRESENT',
          correctionMarks: 40,
          correctionMarkStatus: 'PRESENT',
          remarks: 'Initial marks entry',
          requestedBy: 'sbranch',
          requestedDate: DateTime.parse('2026-09-10T10:00:00.000Z'),
        ),
      ],
    ),
    MarksCorrectionItem(
      examId: 30,
      studentId: 41294,
      studentName: 'Varshitha Reddy',
      rollNo: 'TNS1234',
      admissionNumber: 'TNS1234',
      section: 'B',
      standard: 'Standard 10',
      examName: 'Assignment Test - 1',
      subject: 'Telugu',
      maximumMarks: 50,
      passingMarks: 35,
      currentMarks: 0,
      currentStatus: 'ABSENT',
      correction: Correction(
        status: 'Pending',
        marks: 38,
        markStatus: 'PRESENT',
        reason: 'Absent by mistake',
        requestedBy: 'Bsan@icue',
        requestedDate: DateTime.parse('2026-09-12T06:59:34.077Z'),
      ),
    ),
  ];

  group('MarksCorrectionRequestsPage Widget Tests', () {
    testWidgets(
      'renders app bar, filter chips, and empty state when no items',
      (tester) async {
        mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
          'err': false,
          'message': 'Marks Correction Requests',
          'data': [],
        };

        await tester.pumpWidget(
          buildTestableWidget(const MarksCorrectionRequestsPage()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Marks Correction Requests'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Approved'), findsOneWidget);
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('All'), findsNothing);
        expect(find.byType(TextField), findsOneWidget);

        expect(
          find.text('No pending marks correction requests found.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders correction request cards with details and diffs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
        'err': false,
        'message': 'Marks Correction Requests',
        'data': sampleRequests.map((x) => x.toJson()).toList(),
      };

      await tester.pumpWidget(
        buildTestableWidget(const MarksCorrectionRequestsPage()),
      );
      await tester.pumpAndSettle();

      // Verify student names
      expect(find.text('Sree V'), findsOneWidget);
      expect(find.text('Varshitha Reddy'), findsOneWidget);

      // Verify standards and sections
      expect(find.text('Standard 10 - A'), findsOneWidget);
      expect(find.text('Standard 10 - B'), findsOneWidget);

      // Verify rolls
      expect(find.text('Roll: 123123'), findsOneWidget);
      expect(find.text('Roll: TNS1234'), findsOneWidget);

      // Verify subjects and exam names
      expect(find.text('Assignment Test - 1 • Telugu'), findsNWidgets(2));

      // Verify reasons
      expect(find.text('Re-evaluation of question 4'), findsOneWidget);
      expect(find.text('Absent by mistake'), findsOneWidget);

      // Verify action buttons for pending items
      expect(find.text('Approve'), findsNWidgets(2));
      expect(find.text('Reject'), findsNWidgets(2));

      // Verify delta pill (+5)
      expect(find.text('+5'), findsOneWidget);
    });

    testWidgets('filters items by search query', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
        'err': false,
        'message': 'Marks Correction Requests',
        'data': sampleRequests.map((x) => x.toJson()).toList(),
      };

      await tester.pumpWidget(
        buildTestableWidget(const MarksCorrectionRequestsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sree V'), findsOneWidget);
      expect(find.text('Varshitha Reddy'), findsOneWidget);

      // Enter search text for 'Varshitha'
      await tester.enterText(find.byType(TextField), 'Varshitha');
      await tester.pumpAndSettle();

      expect(find.text('Sree V'), findsNothing);
      expect(find.text('Varshitha Reddy'), findsOneWidget);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sree V'), findsOneWidget);
      expect(find.text('Varshitha Reddy'), findsOneWidget);
    });

    testWidgets('switching status filter chips triggers provider fetch', (
      tester,
    ) async {
      mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
        'err': false,
        'message': 'Marks Correction Requests',
        'data': [],
      };

      await tester.pumpWidget(
        buildTestableWidget(const MarksCorrectionRequestsPage()),
      );
      await tester.pumpAndSettle();

      // Default pending fetch was triggered on init
      expect(
        mockApiClient.lastPostPath,
        equals('/v1.0/getMarksCorrectionRequests'),
      );
      expect(
        mockApiClient.lastPostData,
        equals({'CorrectionStatus': 'Pending'}),
      );

      // Tap 'Approved' chip
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();

      expect(
        mockApiClient.lastPostData,
        equals({'CorrectionStatus': 'Approved'}),
      );

      // Tap 'Rejected' chip
      await tester.tap(find.text('Rejected'));
      await tester.pumpAndSettle();

      expect(
        mockApiClient.lastPostData,
        equals({'CorrectionStatus': 'Rejected'}),
      );
    });

    testWidgets(
      'approving a request opens dialog and calls approveMarksCorrection',
      (tester) async {
        mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
          'err': false,
          'message': 'Marks Correction Requests',
          'data': [sampleRequests.first.toJson()],
        };
        mockApiClient.responsesByPath['/v1.0/approveMarksCorrection'] = {
          'success': true,
          'message': 'Approved successfully',
          'ExamId': 30,
          'StudentId': 41292,
          'Decision': 'Approved',
          'Marks': 40,
          'Status': 'PRESENT',
        };

        await tester.pumpWidget(
          buildTestableWidget(const MarksCorrectionRequestsPage()),
        );
        await tester.pumpAndSettle();

        // Tap Approve on card
        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();

        // Verify dialog is shown
        expect(find.text('Approve Request'), findsOneWidget);
        expect(
          find.text(
            'Are you sure you want to approve the marks correction for Sree V?',
          ),
          findsOneWidget,
        );

        // Tap Approve button inside dialog
        final approveInDialog = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Approve'),
        );
        await tester.tap(approveInDialog);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(
          mockApiClient.lastPostPath,
          equals('/v1.0/approveMarksCorrection'),
        );
        expect(
          mockApiClient.lastPostData,
          equals({
            'ExamId': 30,
            'StudentId': 41292,
            'Decision': 'Approved',
            'Remarks': 'Approved',
          }),
        );
      },
    );

    testWidgets(
      'rejecting a request validates remarks and calls approveMarksCorrection',
      (tester) async {
        mockApiClient.responsesByPath['/v1.0/getMarksCorrectionRequests'] = {
          'err': false,
          'message': 'Marks Correction Requests',
          'data': [sampleRequests.first.toJson()],
        };
        mockApiClient.responsesByPath['/v1.0/approveMarksCorrection'] = {
          'success': true,
          'message': 'Rejected successfully',
          'ExamId': 30,
          'StudentId': 41292,
          'Decision': 'Rejected',
        };

        await tester.pumpWidget(
          buildTestableWidget(const MarksCorrectionRequestsPage()),
        );
        await tester.pumpAndSettle();

        // Tap Reject on card
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();

        // Verify dialog is shown
        expect(find.text('Reject Request'), findsOneWidget);

        // Attempt to submit without reason -> should show validation error
        final rejectInDialog = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reject'),
        );
        await tester.tap(rejectInDialog);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a rejection reason'), findsOneWidget);

        // Enter rejection reason
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          'Marks verified with answer sheet, no error found',
        );
        await tester.pumpAndSettle();

        // Submit reject
        await tester.tap(rejectInDialog);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(
          mockApiClient.lastPostPath,
          equals('/v1.0/approveMarksCorrection'),
        );
        expect(
          mockApiClient.lastPostData,
          equals({
            'ExamId': 30,
            'StudentId': 41292,
            'Decision': 'Rejected',
            'Remarks': 'Marks verified with answer sheet, no error found',
          }),
        );
      },
    );
  });
}
