import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/pages/leaves/leave_balance_page.dart';
import 'package:icueadmin/providers/leave_provider.dart';
import 'package:icueadmin/services/hrms_api_client.dart';
import 'package:provider/provider.dart';

class MockHrmsApiClient extends Fake implements HrmsApiClient {
  String? lastGetPath;
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
    {
      'leavetype_fid': 38,
      'leavetype': 'Maternity Leave (MAL)',
      'description': 'Maternity leave details',
      'is_emp_access': false,
      'noofdays': '15',
      'leavetaken': '4',
      'balanceleave': '11',
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

  group('LeaveBalancePage Widget Tests', () {
    testWidgets('renders title, summary metrics, and leave cards', (
      tester,
    ) async {
      mockHrmsApiClient.nextResponseData = sampleData;
      // Preload data
      await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);

      await tester.pumpWidget(
        buildTestableWidget(const LeaveBalancePage(initialYear: 2026)),
      );
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Leave Balance'), findsOneWidget);

      // Verify summary metrics
      expect(find.text('Total Quota'), findsOneWidget);
      expect(find.text('Taken'), findsWidgets);
      expect(find.text('Balance'), findsWidgets);

      // Total quota is 1 + 1 + 15 = 17
      expect(find.text('17'), findsOneWidget);
      // Total taken is 4
      expect(find.text('4'), findsWidgets);
      // Total balance is 1 + 1 + 11 = 13
      expect(find.text('13'), findsOneWidget);

      // Verify leave cards
      expect(find.text('Assigned Leave (AL)'), findsOneWidget);
      expect(find.text('Casual Leave (CL)'), findsOneWidget);
      expect(find.text('Maternity Leave (MAL)'), findsOneWidget);

      // Verify badges
      expect(find.text('Accessible'), findsNWidgets(2));
      expect(find.text('Restricted'), findsOneWidget);
    });

    testWidgets('filters accessible only leaves via chip', (tester) async {
      mockHrmsApiClient.nextResponseData = sampleData;
      await leaveProvider.fetchLeaveBalances(employeeId: 1, year: 2026);

      await tester.pumpWidget(
        buildTestableWidget(const LeaveBalancePage(initialYear: 2026)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maternity Leave (MAL)'), findsOneWidget);

      // Tap 'Accessible Only' filter chip
      await tester.tap(find.text('Accessible Only'));
      await tester.pumpAndSettle();

      // Restricted maternity leave should now be filtered out
      expect(find.text('Maternity Leave (MAL)'), findsNothing);
      expect(find.text('Assigned Leave (AL)'), findsOneWidget);
      expect(find.text('Casual Leave (CL)'), findsOneWidget);
    });
  });
}
