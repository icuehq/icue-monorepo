import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/pages/leaves/leaves_applied_page.dart';
import 'package:icueadmin/providers/leave_provider.dart';
import 'package:icueadmin/services/hrms_api_client.dart';
import 'package:provider/provider.dart';

class MockHrmsApiClient extends Fake implements HrmsApiClient {
  String? lastGetPath;
  dynamic nextResponseData;
  int nextStatusCode = 200;
  Completer<Response>? pendingGetCompleter;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    lastGetPath = path;
    if (pendingGetCompleter != null) {
      return pendingGetCompleter!.future;
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: nextResponseData ?? [],
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

  final requestedData = [
    {
      'leave_uid': 103,
      'employee_id': 241,
      'leavetype_fid': 38,
      'requestedto_fid': null,
      'requesteddate': '2026-09-16T00:00:00.000Z',
      'fromdate': '2026-09-20T00:00:00.000Z',
      'todate': '2026-09-20T00:00:00.000Z',
      'noofdays': 1,
      'halfday': true,
      'halfdayslot': null,
      'reason': 'Medical observation',
      'approvedorrejectedbyid': null,
      'approveorrejectionremarks': null,
      'status': 'Requested',
      'createdon': '2026-09-16T05:21:57.182Z',
      'createdby': 1,
      'updatedon': null,
      'updatedby': null,
      'org_id': 1,
      'leavetype': 'Maternity Leave (MAL) ',
    },
  ];

  final rejectedData = [
    {
      'leave_uid': 97,
      'employee_id': 241,
      'leavetype_fid': 41,
      'requestedto_fid': null,
      'requesteddate': '2025-01-05T00:00:00.000Z',
      'fromdate': '2025-01-06T00:00:00.000Z',
      'todate': '2025-01-06T00:00:00.000Z',
      'noofdays': 1,
      'halfday': false,
      'halfdayslot': null,
      'reason': 'Family event',
      'approvedorrejectedbyid': 1,
      'approveorrejectionremarks': 'Staff shortage on date',
      'status': 'Rejected',
      'createdon': '2025-01-05T05:38:28.162Z',
      'createdby': 1,
      'updatedon': '2025-01-05T05:39:36.570Z',
      'updatedby': 1,
      'org_id': 1,
      'leavetype': 'Marriage Leave (ML)',
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

  group('LeavesAppliedPage Widget Tests', () {
    testWidgets('renders tabs, count, and application cards', (tester) async {
      mockHrmsApiClient.nextResponseData = requestedData;
      await leaveProvider.fetchAppliedLeaves(
        employeeId: 241,
        status: 'Requested',
      );

      await tester.pumpWidget(buildTestableWidget(const LeavesAppliedPage()));
      await tester.pumpAndSettle();

      expect(find.text('Leaves Applied'), findsOneWidget);
      expect(find.text('Requested'), findsWidgets);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Rejected'), findsWidgets);

      // Verify leave card content
      expect(find.text('Maternity Leave (MAL)'), findsOneWidget);
      expect(
        find.text('Reason: Medical observation'),
        findsNothing,
      ); // label is separate
      expect(find.text('Medical observation'), findsOneWidget);
      expect(find.text('Half Day (0.5d)'), findsOneWidget);
    });

    testWidgets('shows rejection remarks for Rejected leaves', (tester) async {
      mockHrmsApiClient.nextResponseData = rejectedData;
      await leaveProvider.fetchAppliedLeaves(
        employeeId: 241,
        status: 'Rejected',
      );

      await tester.pumpWidget(
        buildTestableWidget(const LeavesAppliedPage(initialStatus: 'Rejected')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marriage Leave (ML)'), findsOneWidget);
      expect(find.text('Remarks: Staff shortage on date'), findsOneWidget);
    });

    testWidgets(
      'shows loading indicator instead of No Data when switching tabs',
      (tester) async {
        mockHrmsApiClient.nextResponseData = requestedData;
        await leaveProvider.fetchAppliedLeaves(
          employeeId: 241,
          status: 'Requested',
        );

        await tester.pumpWidget(buildTestableWidget(const LeavesAppliedPage()));
        await tester.pumpAndSettle();

        expect(find.text('Maternity Leave (MAL)'), findsOneWidget);

        // Setup a pending completer for the Approved GET request
        final completer = Completer<Response>();
        mockHrmsApiClient.pendingGetCompleter = completer;

        // Tap the 'Approved' tab
        await tester.tap(find.widgetWithText(Tab, 'Approved'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // While Approved has not finished loading, verify it shows loading and NOT NoDataWidget
        expect(
          find.text('No Approved leave applications found.'),
          findsNothing,
        );
        expect(
          find.byType(CircularProgressIndicator, skipOffstage: false),
          findsOneWidget,
        );

        // Now complete the response with empty data
        completer.complete(
          Response(
            requestOptions: RequestOptions(
              path: '/api/v1/leaves/by-id-status/241/Approved',
            ),
            data: [],
            statusCode: 200,
          ),
        );
        mockHrmsApiClient.pendingGetCompleter = null;

        await tester.pumpAndSettle();

        // After loading finishes, NoDataWidget should show
        expect(
          find.text('No Approved leave applications found.'),
          findsOneWidget,
        );
      },
    );
  });
}
