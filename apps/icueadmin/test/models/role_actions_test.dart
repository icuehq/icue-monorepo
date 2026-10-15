import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/role_actions.dart';

void main() {
  group('RoleActions JSON parsing for Exam Mgmt', () {
    final actionsJson = [
      {
        'Id': 265,
        'Name': 'Exam Mgmt - Admin App',
        'DisplayName': 'Exam Mgmt',
        'RouteState': 'layout.exams',
        'Icon':
            'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
        'TabOrder': 1,
        'SubActions': true,
        'SubActionItems': [
          {
            'Id': 266,
            'Name': 'Marks Entry - Admin App',
            'DisplayName': 'Marks Entry',
            'RouteState': 'layout.marksentry',
            'Icon':
                'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
            'TabOrder': 1,
          },
          {
            'Id': 267,
            'Name': 'Results - Admin App',
            'DisplayName': 'Results',
            'RouteState': 'layout.exam_results',
            'Icon':
                'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
            'TabOrder': 2,
          },
        ],
      },
    ];

    test('parses exam actions and sub-actions correctly', () {
      final actions = actionsJson.map((x) => RoleActions.fromJson(x)).toList();

      expect(actions.length, equals(1));
      final examMgmt = actions.first;
      expect(examMgmt.id, equals(265));
      expect(examMgmt.name, equals('Exam Mgmt - Admin App'));
      expect(examMgmt.displayName, equals('Exam Mgmt'));
      expect(examMgmt.routeState, equals('layout.exams'));
      expect(
        examMgmt.icon,
        equals(
          'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
        ),
      );
      expect(examMgmt.tabOrder, equals(1));
      expect(examMgmt.subActions, isTrue);

      expect(examMgmt.subActionItems, isNotNull);
      expect(examMgmt.subActionItems!.length, equals(2));

      final marksEntry = examMgmt.subActionItems![0];
      expect(marksEntry.id, equals(266));
      expect(marksEntry.name, equals('Marks Entry - Admin App'));
      expect(marksEntry.displayName, equals('Marks Entry'));
      expect(marksEntry.routeState, equals('layout.marksentry'));
      expect(marksEntry.tabOrder, equals(1));

      final results = examMgmt.subActionItems![1];
      expect(results.id, equals(267));
      expect(results.name, equals('Results - Admin App'));
      expect(results.displayName, equals('Results'));
      expect(results.routeState, equals('layout.exam_results'));
      expect(results.tabOrder, equals(2));
    });

    test('roundtrips through toJson()', () {
      final examMgmt = RoleActions.fromJson(actionsJson.first);
      final jsonMap = examMgmt.toJson();
      final roundtripped = RoleActions.fromJson(jsonMap);

      expect(roundtripped.id, equals(examMgmt.id));
      expect(roundtripped.name, equals(examMgmt.name));
      expect(roundtripped.routeState, equals(examMgmt.routeState));
      expect(roundtripped.subActions, isTrue);
      expect(roundtripped.subActionItems?.length, equals(2));
      expect(
        roundtripped.subActionItems?.first.routeState,
        equals('layout.marksentry'),
      );
    });
  });

  group(
    'RoleActions parsing for getActionsByRole response (Exams, Leaves, Home Assignments)',
    () {
      final responsePayload = [
        {
          'Id': 265,
          'Name': 'Exam Mgmt - Admin App',
          'DisplayName': 'Exam Mgmt',
          'RouteState': 'layout.exams',
          'Icon':
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          'TabOrder': 1,
          'SubActions': true,
          'SubActionItems': [
            {
              'Id': 266,
              'Name': 'Marks Entry - Admin App',
              'DisplayName': 'Marks Entry',
              'RouteState': 'layout.marksentry',
              'Icon':
                  'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
              'TabOrder': 1,
            },
            {
              'Id': 267,
              'Name': 'Results - Admin App',
              'DisplayName': 'Results',
              'RouteState': 'layout.exam_results',
              'Icon':
                  'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
              'TabOrder': 2,
            },
          ],
        },
        {
          'Id': 270,
          'Name': 'Leaves - Admin App',
          'DisplayName': 'Leaves',
          'RouteState': 'layout.leaves',
          'Icon':
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          'TabOrder': 1,
          'SubActions': false,
          'SubActionItems': [],
        },
        {
          'Id': 269,
          'Name': 'Home Assignments - Admin App',
          'DisplayName': 'Home Assignments',
          'RouteState': 'layout.homeassignments',
          'Icon':
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          'TabOrder': 3,
          'SubActions': false,
          'SubActionItems': [],
        },
      ];

      test('parses all actions including Leaves and Home Assignments', () {
        final actions = responsePayload
            .map((x) => RoleActions.fromJson(x))
            .toList();
        expect(actions.length, equals(3));

        // Leaves
        final leaves = actions.firstWhere(
          (a) => a.routeState == 'layout.leaves',
        );
        expect(leaves.id, equals(270));
        expect(leaves.name, equals('Leaves - Admin App'));
        expect(leaves.displayName, equals('Leaves'));
        expect(leaves.tabOrder, equals(1));
        expect(leaves.subActions, isFalse);
        expect(leaves.subActionItems, isEmpty);

        // Home Assignments
        final homeAssignments = actions.firstWhere(
          (a) => a.routeState == 'layout.homeassignments',
        );
        expect(homeAssignments.id, equals(269));
        expect(homeAssignments.name, equals('Home Assignments - Admin App'));
        expect(homeAssignments.displayName, equals('Home Assignments'));
        expect(homeAssignments.tabOrder, equals(3));
        expect(homeAssignments.subActions, isFalse);
        expect(homeAssignments.subActionItems, isEmpty);

        // Sorting by tabOrder
        actions.sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
        expect(actions[0].tabOrder, equals(1));
        expect(actions[1].tabOrder, equals(1));
        expect(actions[2].tabOrder, equals(3));
      });

      test('roundtrips Leaves and Home Assignments through toJson()', () {
        final actions = responsePayload
            .map((x) => RoleActions.fromJson(x))
            .toList();
        for (final action in actions) {
          final jsonMap = action.toJson();
          final roundtripped = RoleActions.fromJson(jsonMap);
          expect(roundtripped.id, equals(action.id));
          expect(roundtripped.name, equals(action.name));
          expect(roundtripped.routeState, equals(action.routeState));
          expect(roundtripped.displayName, equals(action.displayName));
          expect(roundtripped.tabOrder, equals(action.tabOrder));
          expect(roundtripped.subActions, equals(action.subActions));
        }
      });
    },
  );

  group('RoleActions parsing for Principal Login Action Items', () {
    final principalActionsJson = [
      {
        'Id': 265,
        'Name': 'Exam Mgmt - Admin App',
        'DisplayName': 'Exam Mgmt',
        'RouteState': 'layout.exams',
        'Icon':
            'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
        'TabOrder': 1,
        'SubActions': true,
        'SubActionItems': [
          {
            'Id': 268,
            'Name': 'Marks Correction Requests - Admin App',
            'DisplayName': 'Marks Correction Requests',
            'RouteState': 'layout.markscorrectionrequests',
            'Icon':
                'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
            'TabOrder': 3,
          },
        ],
      },
    ];

    test(
      'parses principal Exam Mgmt with Marks Correction Requests sub-action',
      () {
        final actions = principalActionsJson
            .map((x) => RoleActions.fromJson(x))
            .toList();

        expect(actions.length, equals(1));
        final examMgmt = actions.first;
        expect(examMgmt.id, equals(265));
        expect(examMgmt.name, equals('Exam Mgmt - Admin App'));
        expect(examMgmt.displayName, equals('Exam Mgmt'));
        expect(examMgmt.routeState, equals('layout.exams'));
        expect(examMgmt.tabOrder, equals(1));
        expect(examMgmt.subActions, isTrue);
        expect(examMgmt.subActionItems, isNotNull);
        expect(examMgmt.subActionItems!.length, equals(1));

        final correctionRequest = examMgmt.subActionItems!.first;
        expect(correctionRequest.id, equals(268));
        expect(
          correctionRequest.name,
          equals('Marks Correction Requests - Admin App'),
        );
        expect(
          correctionRequest.displayName,
          equals('Marks Correction Requests'),
        );
        expect(
          correctionRequest.routeState,
          equals('layout.markscorrectionrequests'),
        );
        expect(correctionRequest.tabOrder, equals(3));
      },
    );

    test('roundtrips principal action items through toJson()', () {
      final action = RoleActions.fromJson(principalActionsJson.first);
      final jsonMap = action.toJson();
      final roundtripped = RoleActions.fromJson(jsonMap);

      expect(roundtripped.id, equals(265));
      expect(roundtripped.routeState, equals('layout.exams'));
      expect(roundtripped.subActions, isTrue);
      expect(roundtripped.subActionItems?.length, equals(1));
      expect(
        roundtripped.subActionItems?.first.routeState,
        equals('layout.markscorrectionrequests'),
      );
      expect(roundtripped.subActionItems?.first.id, equals(268));
      expect(roundtripped.subActionItems?.first.tabOrder, equals(3));
    });
  });
}
