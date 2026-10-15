import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:icueadmin/models/role_actions.dart';
import 'package:icueadmin/pages/exams/exam_mgmt_page.dart';

void main() {
  late Directory tempDir;
  late Box<RoleActions> actionsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('exam_mgmt_hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RoleActionsAdapter());
    }
    actionsBox = await Hive.openBox<RoleActions>('getActionsByRole-v2');
  });

  tearDownAll(() async {
    await actionsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  tearDown(() async {
    await actionsBox.clear();
  });

  testWidgets(
    'ExamMgmtPage renders ONLY Marks Correction Requests card for Principal login',
    (tester) async {
      // Seed Principal action items
      final principalExamAction = RoleActions(
        id: 265,
        name: 'Exam Mgmt - Admin App',
        displayName: 'Exam Mgmt',
        routeState: 'layout.exams',
        icon: 'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
        tabOrder: 1,
        subActions: true,
        subActionItems: [
          RoleActions(
            id: 268,
            name: 'Marks Correction Requests - Admin App',
            displayName: 'Marks Correction Requests',
            routeState: 'layout.markscorrectionrequests',
            icon:
                'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
            tabOrder: 3,
          ),
        ],
      );

      await actionsBox.put('layout.exams', principalExamAction);

      await tester.pumpWidget(const MaterialApp(home: ExamMgmtPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Exam Management'), findsOneWidget);

      // Principal SHOULD see Marks Correction Requests
      expect(find.text('Marks Correction Requests'), findsOneWidget);
      expect(
        find.text(
          'Review, approve, or reject score correction requests submitted by teachers.',
        ),
        findsOneWidget,
      );
      expect(find.text('Approvals'), findsOneWidget);

      // Principal SHOULD NOT see Marks Entry or Results & Leaderboards
      expect(find.text('Marks Entry'), findsNothing);
      expect(find.text('Results & Leaderboards'), findsNothing);
    },
  );

  testWidgets('ExamMgmtPage renders all 3 cards when role has all sub-actions', (
    tester,
  ) async {
    final fullExamAction = RoleActions(
      id: 265,
      name: 'Exam Mgmt - Admin App',
      displayName: 'Exam Mgmt',
      routeState: 'layout.exams',
      icon: 'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
      tabOrder: 1,
      subActions: true,
      subActionItems: [
        RoleActions(
          id: 266,
          name: 'Marks Entry - Admin App',
          displayName: 'Marks Entry',
          routeState: 'layout.marksentry',
          icon:
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          tabOrder: 1,
        ),
        RoleActions(
          id: 267,
          name: 'Results - Admin App',
          displayName: 'Results & Leaderboards',
          routeState: 'layout.exam_results',
          icon:
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          tabOrder: 2,
        ),
        RoleActions(
          id: 268,
          name: 'Marks Correction Requests - Admin App',
          displayName: 'Marks Correction Requests',
          routeState: 'layout.markscorrectionrequests',
          icon:
              'https://stgthnxdev.blob.core.windows.net/appimgs/Attendance.png',
          tabOrder: 3,
        ),
      ],
    );

    await actionsBox.put('layout.exams', fullExamAction);

    await tester.pumpWidget(const MaterialApp(home: ExamMgmtPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Marks Entry'), findsOneWidget);
    expect(find.text('Results & Leaderboards'), findsOneWidget);
    expect(find.text('Marks Correction Requests'), findsOneWidget);
  });

  testWidgets(
    'ExamMgmtPage renders default fallback cards when subActionItems is empty',
    (tester) async {
      // Empty subActionItems (e.g. unseeded development or full fallback)
      await actionsBox.clear();

      await tester.pumpWidget(const MaterialApp(home: ExamMgmtPage()));
      await tester.pumpAndSettle();

      expect(find.text('Marks Entry'), findsOneWidget);
      expect(find.text('Results & Leaderboards'), findsOneWidget);
      expect(find.text('Marks Correction Requests'), findsOneWidget);
    },
  );
}
