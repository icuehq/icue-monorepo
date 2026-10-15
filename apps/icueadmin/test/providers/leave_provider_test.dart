import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/leave_request.dart';
import 'package:icueadmin/providers/leave_provider.dart';
import 'package:icueadmin/services/hrms_api_client.dart';

class MockHrmsApiClient extends Fake implements HrmsApiClient {
  String? lastGetPath;
  dynamic nextResponseData;
  int nextStatusCode = 200;
  bool shouldThrow = false;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    lastGetPath = path;
    if (shouldThrow) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Network failure',
      );
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: nextResponseData ?? [],
      statusCode: nextStatusCode,
    );
  }

  String? lastPostPath;
  dynamic lastPostData;
  int nextPostStatusCode = 200;
  dynamic nextPostResponseData;
  bool shouldPostThrow = false;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    if (shouldPostThrow) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Network failure',
      );
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: nextPostResponseData ?? {'message': 'Success'},
      statusCode: nextPostStatusCode,
    );
  }

  @override
  String extractErrorMessage(DioException error) =>
      error.message ?? 'Network failure';

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
      'leavetype_fid': 38,
      'leavetype': 'Maternity Leave (MAL) ',
      'description': 'Description',
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

  group('LeaveProvider Tests', () {
    test(
      'fetches leave balances successfully and sets path with empid and year',
      () async {
        mockHrmsApiClient.nextResponseData = sampleData;

        await leaveProvider.fetchLeaveBalances(employeeId: 101, year: 2026);

        expect(
          mockHrmsApiClient.lastGetPath,
          equals('/api/v1/leaves/by-empid/101/2026'),
        );
        expect(leaveProvider.loading, isFalse);
        expect(leaveProvider.errorMessage, isNull);
        expect(leaveProvider.leaveBalances.length, equals(2));

        // Check metric computations
        expect(leaveProvider.totalAllocated, equals(16.0));
        expect(leaveProvider.totalTaken, equals(4.0));
        expect(leaveProvider.totalBalance, equals(12.0));
      },
    );

    test('filters accessible only leaves', () async {
      mockHrmsApiClient.nextResponseData = sampleData;
      await leaveProvider.fetchLeaveBalances(employeeId: 101, year: 2026);

      expect(leaveProvider.displayedLeaves.length, equals(2));

      leaveProvider.setFilterAccessibleOnly(true);
      expect(leaveProvider.displayedLeaves.length, equals(1));
      expect(leaveProvider.displayedLeaves.first.leavetypeFid, equals(82));
    });

    test('handles API error properly', () async {
      mockHrmsApiClient.shouldThrow = true;

      await leaveProvider.fetchLeaveBalances(employeeId: 101, year: 2026);

      expect(leaveProvider.loading, isFalse);
      expect(leaveProvider.errorMessage, isNotNull);
      expect(leaveProvider.leaveBalances, isEmpty);
    });

    test('handles non-200 response', () async {
      mockHrmsApiClient.nextStatusCode = 500;
      mockHrmsApiClient.nextResponseData = null;

      await leaveProvider.fetchLeaveBalances(employeeId: 101, year: 2026);

      expect(leaveProvider.loading, isFalse);
      expect(
        leaveProvider.errorMessage,
        equals('Failed to load leave balances.'),
      );
    });

    group('submitLeaveRequest', () {
      final testPayload = const LeaveRequestPayload(
        leavetypeFid: 82,
        leavetype: 'Assigned Leave (AL)',
        leavebalance: 1,
        employeeId: 101,
        fromdate: '2026-09-15',
        todate: '2026-09-15',
        noofdays: 1,
        reason: 'Personal work',
        halfday: false,
        createdby: 101,
      );

      test(
        'submits leave request successfully and refreshes balances',
        () async {
          mockHrmsApiClient.nextPostStatusCode = 200;
          mockHrmsApiClient.nextResponseData = sampleData;

          final result = await leaveProvider.submitLeaveRequest(testPayload);

          expect(result, isTrue);
          expect(mockHrmsApiClient.lastPostPath, equals('/api/v1/leaves'));
          expect(mockHrmsApiClient.lastPostData['leavetype_fid'], equals(82));
          expect(mockHrmsApiClient.lastPostData['employee_id'], equals(101));
          expect(mockHrmsApiClient.lastPostData['status'], equals('Requested'));
          expect(leaveProvider.submitting, isFalse);
          expect(leaveProvider.errorMessage, isNull);
        },
      );

      test('handles submission HTTP failure', () async {
        mockHrmsApiClient.nextPostStatusCode = 400;

        final result = await leaveProvider.submitLeaveRequest(testPayload);

        expect(result, isFalse);
        expect(leaveProvider.submitting, isFalse);
        expect(
          leaveProvider.errorMessage,
          equals('Failed to submit leave request.'),
        );
      });

      test('handles submission network exception', () async {
        mockHrmsApiClient.shouldPostThrow = true;

        final result = await leaveProvider.submitLeaveRequest(testPayload);

        expect(result, isFalse);
        expect(leaveProvider.submitting, isFalse);
        expect(
          leaveProvider.errorMessage,
          equals('Failed to submit leave request. Please try again.'),
        );
      });
    });

    group('fetchAppliedLeaves', () {
      final appliedSample = [
        {
          'leave_uid': 103,
          'employee_id': 101,
          'leavetype_fid': 38,
          'requestedto_fid': null,
          'requesteddate': '2026-09-16T00:00:00.000Z',
          'fromdate': '2026-09-20T00:00:00.000Z',
          'todate': '2026-09-20T00:00:00.000Z',
          'noofdays': 1,
          'halfday': true,
          'halfdayslot': null,
          'reason': 'Test',
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

      test('fetches Requested leaves and updates state', () async {
        mockHrmsApiClient.nextResponseData = appliedSample;

        await leaveProvider.fetchAppliedLeaves(
          employeeId: 101,
          status: 'Requested',
        );

        expect(
          mockHrmsApiClient.lastGetPath,
          equals('/api/v1/leaves/by-id-status/101/Requested'),
        );
        expect(leaveProvider.loadingApplied, isFalse);
        expect(leaveProvider.selectedAppliedStatus, equals('Requested'));
        expect(leaveProvider.currentAppliedLeaves.length, equals(1));
        expect(leaveProvider.appliedCount('Requested'), equals(1));
        expect(leaveProvider.currentAppliedLeaves.first.leaveUid, equals(103));
      });

      test('fetches Approved leaves when status switches', () async {
        mockHrmsApiClient.nextResponseData = [
          {
            'leave_uid': 99,
            'employee_id': 101,
            'leavetype_fid': 82,
            'requestedto_fid': null,
            'requesteddate': '2025-01-23T00:00:00.000Z',
            'fromdate': '2025-01-13T00:00:00.000Z',
            'todate': '2025-01-13T00:00:00.000Z',
            'noofdays': 1,
            'halfday': true,
            'halfdayslot': null,
            'reason': 'Medical checkup',
            'approvedorrejectedbyid': 1,
            'approveorrejectionremarks': 'test',
            'status': 'Approved',
            'createdon': '2025-01-23T02:18:25.956Z',
            'createdby': 1,
            'updatedon': null,
            'updatedby': null,
            'org_id': 1,
            'leavetype': 'Assigned Leave (AL)',
          },
        ];

        await leaveProvider.fetchAppliedLeaves(
          employeeId: 101,
          status: 'Approved',
        );

        expect(
          mockHrmsApiClient.lastGetPath,
          equals('/api/v1/leaves/by-id-status/101/Approved'),
        );
        expect(leaveProvider.selectedAppliedStatus, equals('Approved'));
        expect(leaveProvider.currentAppliedLeaves.length, equals(1));
        expect(leaveProvider.appliedCount('Approved'), equals(1));
        expect(
          leaveProvider.currentAppliedLeaves.first.status,
          equals('Approved'),
        );
        expect(leaveProvider.hasLoadedAppliedLeaves('Approved'), isTrue);
        expect(leaveProvider.hasLoadedAppliedLeaves('Rejected'), isFalse);
      });

      test(
        'does not re-fetch if already loaded unless refresh is true',
        () async {
          mockHrmsApiClient.nextResponseData = appliedSample;
          await leaveProvider.fetchAppliedLeaves(
            employeeId: 101,
            status: 'Requested',
          );
          mockHrmsApiClient.lastGetPath = null;

          // Call again without refresh
          await leaveProvider.fetchAppliedLeaves(
            employeeId: 101,
            status: 'Requested',
          );
          expect(mockHrmsApiClient.lastGetPath, isNull);

          // Call with refresh
          await leaveProvider.fetchAppliedLeaves(
            employeeId: 101,
            status: 'Requested',
            refresh: true,
          );
          expect(
            mockHrmsApiClient.lastGetPath,
            equals('/api/v1/leaves/by-id-status/101/Requested'),
          );
        },
      );
    });
  });
}
