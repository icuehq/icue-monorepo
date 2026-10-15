import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/leave_application.dart';

void main() {
  group('LeaveApplication Model Tests', () {
    final requestedJson = [
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
      {
        'leave_uid': 102,
        'employee_id': 241,
        'leavetype_fid': 38,
        'requestedto_fid': null,
        'requesteddate': '2026-09-15T00:00:00.000Z',
        'fromdate': '2026-09-18T00:00:00.000Z',
        'todate': '2026-09-19T00:00:00.000Z',
        'noofdays': 2,
        'halfday': true,
        'halfdayslot': null,
        'reason': 'Test',
        'approvedorrejectedbyid': null,
        'approveorrejectionremarks': null,
        'status': 'Requested',
        'createdon': '2026-09-15T03:54:06.235Z',
        'createdby': 1,
        'updatedon': null,
        'updatedby': null,
        'org_id': 1,
        'leavetype': 'Maternity Leave (MAL) ',
      },
    ];

    final rejectedJson = [
      {
        'leave_uid': 97,
        'employee_id': 241,
        'leavetype_fid': 41,
        'requestedto_fid': null,
        'requesteddate': '2025-01-05T00:00:00.000Z',
        'fromdate': '2025-01-06T00:00:00.000Z',
        'todate': '2025-01-06T00:00:00.000Z',
        'noofdays': 1,
        'halfday': true,
        'halfdayslot': null,
        'reason': 'ASD SADSAD',
        'approvedorrejectedbyid': 1,
        'approveorrejectionremarks': 'rejected  leave request',
        'status': 'Rejected',
        'createdon': '2025-01-05T05:38:28.162Z',
        'createdby': 1,
        'updatedon': '2025-01-05T05:39:36.570Z',
        'updatedby': 1,
        'org_id': 1,
        'leavetype': 'Marriage Leave (ML)',
      },
    ];

    final approvedJson = [
      {
        'leave_uid': 99,
        'employee_id': 241,
        'leavetype_fid': 82,
        'requestedto_fid': null,
        'requesteddate': '2025-01-23T00:00:00.000Z',
        'fromdate': '2025-01-13T00:00:00.000Z',
        'todate': '2025-01-13T00:00:00.000Z',
        'noofdays': 1,
        'halfday': true,
        'halfdayslot': null,
        'reason': 'SFSFSFDS FSD',
        'approvedorrejectedbyid': 1,
        'approveorrejectionremarks': 'test',
        'status': 'Approved',
        'createdon': '2025-01-23T02:18:25.956Z',
        'createdby': 1,
        'updatedon': '2026-09-12T05:20:16.516Z',
        'updatedby': 1,
        'org_id': 1,
        'leavetype': 'Assigned Leave (AL)',
      },
    ];

    test('parses Requested leaves correctly', () {
      final list = leaveApplicationListFromJson(requestedJson);
      expect(list.length, equals(2));

      final first = list.first;
      expect(first.leaveUid, equals(103));
      expect(first.employeeId, equals(241));
      expect(first.leavetypeFid, equals(38));
      expect(first.leaveType, equals('Maternity Leave (MAL)'));
      expect(first.status, equals('Requested'));
      expect(first.halfDay, isTrue);
      expect(first.formattedDuration, equals('Half Day (0.5d)'));
      expect(first.reason, equals('Test'));
    });

    test('parses Rejected leaves with remarks correctly', () {
      final list = leaveApplicationListFromJson(rejectedJson);
      expect(list.length, equals(1));

      final item = list.first;
      expect(item.leaveUid, equals(97));
      expect(item.status, equals('Rejected'));
      expect(item.approveOrRejectionRemarks, equals('rejected  leave request'));
      expect(item.leaveType, equals('Marriage Leave (ML)'));
    });

    test('parses Approved leaves correctly', () {
      final list = leaveApplicationListFromJson(approvedJson);
      expect(list.length, equals(1));

      final item = list.first;
      expect(item.leaveUid, equals(99));
      expect(item.status, equals('Approved'));
      expect(item.approveOrRejectionRemarks, equals('test'));
    });

    test('serializes to JSON correctly', () {
      final list = leaveApplicationListFromJson(requestedJson);
      final jsonStr = leaveApplicationListToJson(list);
      expect(jsonStr.contains('Maternity Leave (MAL)'), isTrue);

      final roundtripped = leaveApplicationListFromJson(jsonStr);
      expect(roundtripped.length, equals(2));
      expect(roundtripped[0].leaveUid, equals(103));
    });
  });
}
