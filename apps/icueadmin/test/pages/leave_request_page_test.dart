import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/pages/leaves/leave_request_page.dart';
import 'package:icueadmin/providers/leave_provider.dart';
import 'package:icueadmin/services/hrms_api_client.dart';
import 'package:provider/provider.dart';

class MockHrmsApiClient extends Fake implements HrmsApiClient {
  String? lastGetPath;
  String? lastPostPath;
  dynamic lastPostData;
  dynamic nextResponseData;
  int nextStatusCode = 200;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    lastGetPath = path;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: nextResponseData ?? [],
      statusCode: nextStatusCode,
    );
  }

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {'message': 'Success'},
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
  late MockHrmsApiClient mockHrmsApiClient;
  late LeaveProvider leaveProvider;

  final sampleData = [
    {
      'leavetype_fid': 82,
      'leavetype': 'Assigned Leave (AL)',
      'description': '1.5 leave per month',
      'is_emp_access': true,
      'noofdays': '1',
      'leavetaken': '0',
      'balanceleave': '1',
      'isvalid': false,
    },
    {
      'leavetype_fid': 48,
      'leavetype': 'Casual Leave (CL)',
      'description': '1 leave per month',
      'is_emp_access': true,
      'noofdays': '1',
      'leavetaken': '0',
      'balanceleave': '1',
      'isvalid': false,
    },
  ];

  setUp(() {
    mockHrmsApiClient = MockHrmsApiClient();
    leaveProvider = LeaveProvider(mockHrmsApiClient);
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<LeaveProvider>.value(
      value: leaveProvider,
      child: MaterialApp(home: child),
    );
  }

  group('LeaveRequestPage Widget Tests', () {
    testWidgets('renders all form fields correctly', (tester) async {
      mockHrmsApiClient.nextResponseData = sampleData;
      await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);

      await tester.pumpWidget(buildTestableWidget(const LeaveRequestPage()));
      await tester.pumpAndSettle();

      expect(find.text('Leave Request'), findsOneWidget);
      expect(find.text('Leave Category'), findsOneWidget);
      expect(find.text('Dates & Duration'), findsOneWidget);
      expect(find.text('Half Day Leave'), findsOneWidget);
      expect(find.text('Reason for Leave'), findsOneWidget);
      expect(find.textContaining('Submit Request'), findsOneWidget);
    });

    testWidgets('validates required reason field on submit', (tester) async {
      mockHrmsApiClient.nextResponseData = sampleData;
      await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);

      await tester.pumpWidget(buildTestableWidget(const LeaveRequestPage()));
      await tester.pumpAndSettle();

      // Submit without entering reason
      await tester.ensureVisible(find.textContaining('Submit Request'));
      await tester.tap(find.textContaining('Submit Request'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a reason for this leave request.'),
        findsOneWidget,
      );
    });

    testWidgets('toggling half day switch updates button duration to 0.5 Day', (
      tester,
    ) async {
      mockHrmsApiClient.nextResponseData = sampleData;
      await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);

      await tester.pumpWidget(buildTestableWidget(const LeaveRequestPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Submit Request (1 Day)'), findsOneWidget);

      // Toggle half day switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.textContaining('Submit Request (0.5 Days)'), findsOneWidget);
    });

    testWidgets(
      'initializes selection safely when balances load asynchronously without throwing setState during build',
      (tester) async {
        mockHrmsApiClient.nextResponseData = sampleData;

        // Mount the widget before balances are loaded
        await tester.pumpWidget(buildTestableWidget(const LeaveRequestPage()));
        // Trigger async fetch while mounted
        await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Leave Request'), findsOneWidget);
        expect(find.text('Assigned Leave (AL)'), findsOneWidget);
      },
    );
  });
}
