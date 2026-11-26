import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_example/main.dart';
import 'package:icue_example/school_config.dart';
import 'package:icue_example/select_student_page.dart';
import 'package:icue_example/session_manager.dart';
import 'package:icue_example/student_dashboard_page.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await IcueSdk.resetForTesting();
  });

  tearDown(() async {
    await IcueSdk.resetForTesting();
  });

  testWidgets(
    'Initial launch without saved session renders SelectStudentPage',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(savedSession: null));
      await tester.pumpAndSettle();

      expect(find.byType(SelectStudentPage), findsOneWidget);
      expect(find.text('Select Student'), findsOneWidget);
      expect(find.text('Select School'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.byType(StudentDashboardPage), findsNothing);
    },
  );

  testWidgets('Launch with saved session renders StudentDashboardPage', (
    WidgetTester tester,
  ) async {
    const mockSchool = SchoolConfig(
      id: 'test_school',
      name: 'Test School Academy',
      apiKey: 'mock-key',
      apiUser: 'mock-user',
      studentIds: ['STU1001'],
      env: IcueEnvironment.dev,
    );
    const session = UserSession(school: mockSchool, studentId: 'STU1001');

    await tester.pumpWidget(const MyApp(savedSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(StudentDashboardPage), findsOneWidget);
    expect(find.text('Student Dashboard'), findsOneWidget);
    expect(find.text('Student ID: STU1001'), findsOneWidget);
    expect(find.text('Test School Academy'), findsWidgets);
    expect(find.text('Track School Bus'), findsOneWidget);
    expect(find.byType(SelectStudentPage), findsNothing);
  });

  testWidgets(
    'Signing in on SelectStudentPage navigates to StudentDashboardPage and saves session',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(savedSession: null));
      await tester.pumpAndSettle();

      // Find the first student "Sign In" button in the list and tap it
      final signInButtons = find.widgetWithText(Container, 'Sign In');
      expect(signInButtons, findsWidgets);

      await tester.tap(signInButtons.first);
      await tester.pumpAndSettle();

      // Should now be on StudentDashboardPage
      expect(find.byType(StudentDashboardPage), findsOneWidget);
      expect(find.text('Student Dashboard'), findsOneWidget);
      expect(find.text('Track School Bus'), findsOneWidget);

      // Verify session is stored locally
      final storedSession = await SessionManager.getSession();
      expect(storedSession, isNotNull);
      expect(storedSession!.studentId, 'UT1234000');
    },
  );

  testWidgets('StudentDashboardPage logout dialog can be cancelled', (
    WidgetTester tester,
  ) async {
    const mockSchool = SchoolConfig(
      id: 'test_school',
      name: 'Test School Academy',
      apiKey: 'mock-key',
      apiUser: 'mock-user',
      studentIds: ['STU1001'],
      env: IcueEnvironment.dev,
    );
    const session = UserSession(school: mockSchool, studentId: 'STU1001');

    await tester.pumpWidget(
      const MaterialApp(home: StudentDashboardPage(session: session)),
    );
    await tester.pumpAndSettle();

    // Tap logout icon in AppBar
    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Sign Out'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog is dismissed, still on StudentDashboardPage
    expect(find.byType(StudentDashboardPage), findsOneWidget);
  });

  testWidgets('StudentDashboardPage logout confirms and clears session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'icue_example_user_session': '{"school":{"id":"test_school","name":"Test School","apiKey":"key","apiUser":"user","studentIds":["STU1"],"env":"dev"},"studentId":"STU1"}',
    });

    const mockSchool = SchoolConfig(
      id: 'test_school',
      name: 'Test School',
      apiKey: 'key',
      apiUser: 'user',
      studentIds: ['STU1'],
      env: IcueEnvironment.dev,
    );
    const session = UserSession(school: mockSchool, studentId: 'STU1');

    await tester.pumpWidget(
      const MaterialApp(home: StudentDashboardPage(session: session)),
    );
    await tester.pumpAndSettle();

    // Tap AppBar logout icon
    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pumpAndSettle();

    // Tap Confirm 'Sign Out' in AlertDialog
    final confirmBtn = find.widgetWithText(FilledButton, 'Sign Out');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Navigated to SelectStudentPage
    expect(find.byType(SelectStudentPage), findsOneWidget);

    // Verify SessionManager has no active session
    final storedSession = await SessionManager.getSession();
    expect(storedSession, isNull);
  });
}
