import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/leave_balance.dart';

void main() {
  group('LeaveBalance Model Tests', () {
    final sampleJson = [
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
        'leavetype_fid': 39,
        'leavetype': 'Bereavement Leave',
        'description':
            'In case of an unfortunate demise in the family (Father/Mother/Spouse/Siblings)',
        'is_emp_access': false,
        'noofdays': '0',
        'leavetaken': '0',
        'balanceleave': '0',
        'isvalid': true,
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
        'leavetype_fid': 45,
        'leavetype': 'Earned Leave',
        'description': 'Earned Leave',
        'is_emp_access': true,
        'noofdays': '0',
        'leavetaken': '0',
        'balanceleave': '0',
        'isvalid': false,
      },
      {
        'leavetype_fid': 41,
        'leavetype': 'Marriage Leave (ML)',
        'description': 'For own marriage. Only once in career at Organization',
        'is_emp_access': true,
        'noofdays': '2',
        'leavetaken': '0',
        'balanceleave': '2',
        'isvalid': false,
      },
      {
        'leavetype_fid': 38,
        'leavetype': 'Maternity Leave (MAL) ',
        'description':
            'Should have worked for 160 days in the 12 months preceding the date of Expected delivery',
        'is_emp_access': false,
        'noofdays': '15',
        'leavetaken': '4',
        'balanceleave': '11',
        'isvalid': false,
      },
      {
        'leavetype_fid': 40,
        'leavetype': 'Paternity Leave (PAL)',
        'description':
            'Male, married employees. Only twice in career at Organization',
        'is_emp_access': false,
        'noofdays': '0',
        'leavetaken': '0',
        'balanceleave': '0',
        'isvalid': true,
      },
      {
        'leavetype_fid': 47,
        'leavetype': 'Sick Leave',
        'description': '1.5 leaves on quarterly basis',
        'is_emp_access': true,
        'noofdays': '0',
        'leavetaken': '0',
        'balanceleave': '0',
        'isvalid': true,
      },
    ];

    test('parses full leave balance payload correctly', () {
      final list = leaveBalanceListFromJson(sampleJson);
      expect(list.length, equals(8));

      // Test item 1 (Assigned Leave)
      final al = list[0];
      expect(al.leavetypeFid, equals(82));
      expect(al.leavetype, equals('Assigned Leave (AL)'));
      expect(al.description, equals('1.5 leave per month'));
      expect(al.isEmpAccess, isTrue);
      expect(al.noOfDays, equals('1'));
      expect(al.allocatedDays, equals(1.0));
      expect(al.leaveTaken, equals('0'));
      expect(al.takenDays, equals(0.0));
      expect(al.balanceLeave, equals('1'));
      expect(al.remainingDays, equals(1.0));
      expect(al.isValid, isFalse);

      // Test item 6 (Maternity Leave - whitespace trimmed and numeric values)
      final mal = list[5];
      expect(mal.leavetypeFid, equals(38));
      expect(mal.leavetype, equals('Maternity Leave (MAL)'));
      expect(mal.isEmpAccess, isFalse);
      expect(mal.allocatedDays, equals(15.0));
      expect(mal.takenDays, equals(4.0));
      expect(mal.remainingDays, equals(11.0));

      // Test item 8 (Sick Leave)
      final sl = list[7];
      expect(sl.leavetypeFid, equals(47));
      expect(sl.leavetype, equals('Sick Leave'));
      expect(sl.isEmpAccess, isTrue);
      expect(sl.isValid, isTrue);
    });

    test('serializes to JSON correctly', () {
      final list = leaveBalanceListFromJson(sampleJson);
      final jsonString = leaveBalanceListToJson(list);
      expect(jsonString.contains('Assigned Leave (AL)'), isTrue);

      final roundtripped = leaveBalanceListFromJson(jsonString);
      expect(roundtripped.length, equals(8));
      expect(roundtripped[0].leavetypeFid, equals(82));
    });

    test('handles wrapped Map response structure', () {
      final wrapped = {'err': false, 'message': 'success', 'data': sampleJson};
      final list = leaveBalanceListFromJson(wrapped);
      expect(list.length, equals(8));
    });

    test('handles null and invalid data gracefully', () {
      expect(leaveBalanceListFromJson(null), isEmpty);
      expect(leaveBalanceListFromJson('invalid json string'), isEmpty);
      expect(leaveBalanceListFromJson({}), isEmpty);
    });
  });
}
