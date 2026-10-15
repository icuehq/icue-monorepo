import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/leave_request.dart';

void main() {
  group('LeaveRequestPayload Model Tests', () {
    final exampleJson = {
      'leave_uid': 0,
      'leavetype_fid': 1,
      'leavetype': 'Casual Leave',
      'leavebalance': 10,
      'employee_id': 123,
      'fromdate': '2026-09-15',
      'todate': '2026-09-15',
      'noofdays': 1,
      'reason': 'Personal work',
      'status': 'Requested',
      'halfday': false,
      'createdby': 1,
    };

    test('serializes to JSON correctly matching API specification', () {
      final payload = const LeaveRequestPayload(
        leavetypeFid: 1,
        leavetype: 'Casual Leave',
        leavebalance: 10,
        employeeId: 123,
        fromdate: '2026-09-15',
        todate: '2026-09-15',
        noofdays: 1,
        reason: 'Personal work',
        halfday: false,
        createdby: 1,
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['leave_uid'], equals(0));
      expect(jsonMap['leavetype_fid'], equals(1));
      expect(jsonMap['leavetype'], equals('Casual Leave'));
      expect(jsonMap['leavebalance'], equals(10));
      expect(jsonMap['employee_id'], equals(123));
      expect(jsonMap['fromdate'], equals('2026-09-15'));
      expect(jsonMap['todate'], equals('2026-09-15'));
      expect(jsonMap['noofdays'], equals(1));
      expect(jsonMap['reason'], equals('Personal work'));
      expect(jsonMap['status'], equals('Requested'));
      expect(jsonMap['halfday'], isFalse);
      expect(jsonMap['createdby'], equals(1));
    });

    test('deserializes from JSON correctly', () {
      final payload = LeaveRequestPayload.fromJson(exampleJson);
      expect(payload.leaveUid, equals(0));
      expect(payload.leavetypeFid, equals(1));
      expect(payload.leavetype, equals('Casual Leave'));
      expect(payload.leavebalance, equals(10));
      expect(payload.employeeId, equals(123));
      expect(payload.fromdate, equals('2026-09-15'));
      expect(payload.todate, equals('2026-09-15'));
      expect(payload.noofdays, equals(1));
      expect(payload.reason, equals('Personal work'));
      expect(payload.status, equals('Requested'));
      expect(payload.halfday, isFalse);
      expect(payload.createdby, equals(1));
    });

    test('supports string-encoded and decimal values', () {
      final jsonWithStrings = {
        'leave_uid': '0',
        'leavetype_fid': '48',
        'leavetype': 'Sick Leave',
        'leavebalance': '1.5',
        'employee_id': '456',
        'fromdate': '2026-09-20',
        'todate': '2026-09-20',
        'noofdays': 0.5,
        'reason': 'Doctor appointment',
        'status': 'Requested',
        'halfday': 'true',
        'createdby': '456',
      };

      final payload = LeaveRequestPayload.fromJson(jsonWithStrings);
      expect(payload.leavetypeFid, equals(48));
      expect(payload.employeeId, equals(456));
      expect(payload.noofdays, equals(0.5));
      expect(payload.halfday, isTrue);
      expect(payload.createdby, equals(456));
    });
  });
}
