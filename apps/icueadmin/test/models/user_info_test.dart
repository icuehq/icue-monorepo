import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/user_info.dart';

void main() {
  group('UserInfo JSON parsing for Teacher Role', () {
    final teacherJson = <String, dynamic>{
      'Id': 3635,
      'Name': 'P Satya Nikita',
      'UserName': '9848012345',
      'OrganizationId': 19,
      'ZoneId': 13,
      'BranchId': 17,
      'Roles': [
        {'Id': 5, 'Name': 'Teacher'},
      ],
      'Classes': [
        {
          'Standard': 'Grade 6',
          'ClassId': 6165,
          'Sections': ['A'],
          'SubjectInfo': [
            {
              'Section': 'A',
              'Subjects': [
                {'SubjectId': 7, 'Subject': 'Social'},
              ],
            },
          ],
        },
        {
          'Standard': 'Grade 7',
          'ClassId': 6166,
          'Sections': ['A'],
          'SubjectInfo': [
            {
              'Section': 'A',
              'Subjects': [
                {'SubjectId': 7, 'Subject': 'Social'},
              ],
            },
          ],
        },
        {
          'Standard': 'Grade 8',
          'ClassId': 6167,
          'Sections': ['A'],
          'SubjectInfo': [
            {
              'Section': 'A',
              'Subjects': [
                {'SubjectId': 7, 'Subject': 'Social'},
              ],
            },
          ],
        },
        {
          'Standard': 'Grade 9',
          'ClassId': 6168,
          'Sections': ['A'],
          'SubjectInfo': [
            {
              'Section': 'A',
              'Subjects': [
                {'SubjectId': 7, 'Subject': 'Social'},
              ],
            },
          ],
        },
        {
          'Standard': 'Grade 10',
          'ClassId': 6169,
          'Sections': ['A'],
          'SubjectInfo': [
            {
              'Section': 'A',
              'Subjects': [
                {'SubjectId': 7, 'Subject': 'Social'},
              ],
            },
          ],
        },
      ],
      'Mobile': 9848012345,
      'Sesid': '0c517400-402d-b19b-194e-73fdb5a3f570',
      'IsCorporate': false,
      'IsLogistics': false,
      'OrgType': 'School',
      'TypeOfBusiness': '',
      'LoginType': 'icue',
      'WardId': null,
      'EnableVirtualClassRoom': true,
      'EnableVroomMeeting': false,
      'EnableVroomITAdminApproval': false,
      'EnableVoice': false,
      'isWebRTCEnabled': true,
      'isTextChatEnabled': false,
      'isAudioBridgeEnabled': false,
      'isTeacherConfigurationEnabled': true,
      'Token': 'mock_token_string',
      'IsFirstLogin': false,
    };

    test('parses teacher response correctly', () {
      final user = UserInfo.fromJson(teacherJson);

      expect(user.id, equals(3635));
      expect(user.name, equals('P Satya Nikita'));
      expect(user.userName, equals('9848012345'));
      expect(user.organizationId, equals(19));
      expect(user.zoneId, equals(13));
      expect(user.branchId, equals(17));
      expect(user.roles.length, equals(1));
      expect(user.roles.first.id, equals(5));
      expect(user.roles.first.name, equals('Teacher'));

      // Mobile is dynamic (can be int or String)
      expect(user.mobile, equals(9848012345));

      // Feature flags
      expect(user.enableVirtualClassRoom, isTrue);
      expect(user.enableVroomMeeting, isFalse);
      expect(user.enableVroomItAdminApproval, isFalse);
      expect(user.enableVoice, isFalse);
      expect(user.isWebRtcEnabled, isTrue);
      expect(user.isTextChatEnabled, isFalse);
      expect(user.isAudioBridgeEnabled, isFalse);
      expect(user.isTeacherConfigurationEnabled, isTrue);

      // Classes and SubjectInfo
      expect(user.classes, isA<List<UserClass>>());
      final classes = user.classes as List<UserClass>;
      expect(classes.length, equals(5));

      final grade6 = classes[0];
      expect(grade6.standard, equals('Grade 6'));
      expect(grade6.classId, equals(6165));
      expect(grade6.sections, equals(['A']));
      expect(grade6.subjectInfo, isNotNull);
      expect(grade6.subjectInfo!.length, equals(1));
      expect(grade6.subjectInfo!.first.section, equals('A'));
      expect(grade6.subjectInfo!.first.subjects.length, equals(1));
      expect(grade6.subjectInfo!.first.subjects.first.subjectId, equals(7));
      expect(
        grade6.subjectInfo!.first.subjects.first.subject,
        equals('Social'),
      );

      final grade10 = classes[4];
      expect(grade10.standard, equals('Grade 10'));
      expect(grade10.classId, equals(6169));
      expect(grade10.sections, equals(['A']));
      expect(grade10.subjectInfo, isNotNull);
      expect(
        grade10.subjectInfo!.first.subjects.first.subject,
        equals('Social'),
      );
    });

    test('roundtrips through toJson()', () {
      final user = UserInfo.fromJson(teacherJson);
      final jsonMap = user.toJson();
      final roundtripped = UserInfo.fromJson(jsonMap);

      expect(roundtripped.id, equals(user.id));
      expect(roundtripped.name, equals(user.name));
      expect(roundtripped.mobile, equals(user.mobile));
      expect(roundtripped.isTeacherConfigurationEnabled, isTrue);
      final rtClasses = roundtripped.classes as List<UserClass>;
      expect(rtClasses.length, equals(5));
      expect(
        rtClasses.first.subjectInfo?.first.subjects.first.subject,
        equals('Social'),
      );
    });

    test('handles classes without subjectInfo and string classes', () {
      final nonTeacherJson = Map<String, dynamic>.from(teacherJson);
      nonTeacherJson['Classes'] = [
        {
          'Standard': 'Grade 1',
          'ClassId': 1001,
          'Sections': ['A', 'B'],
        },
      ];
      final user = UserInfo.fromJson(nonTeacherJson);
      final classes = user.classes as List<UserClass>;
      expect(classes.first.subjectInfo, isNull);

      nonTeacherJson['Classes'] = 'ALL';
      final userWithStringClasses = UserInfo.fromJson(nonTeacherJson);
      expect(userWithStringClasses.classes, equals('ALL'));
    });
  });
}
