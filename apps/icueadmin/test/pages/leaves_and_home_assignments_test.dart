import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/assigned_entities.dart';
import 'package:icueadmin/pages/home_assignments/create_home_assignment_page.dart';
import 'package:icueadmin/pages/home_assignments/home_assignments_page.dart';
import 'package:icueadmin/pages/leaves/leaves_page.dart';
import 'package:icueadmin/providers/auth_provider.dart';
import 'package:icueadmin/providers/home_assignment_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:provider/provider.dart';

class MockApiClient extends Fake implements ApiClient {
  dynamic lastPostData;
  String? lastPostPath;
  dynamic nextResponseData;
  int nextStatusCode = 200;

  @override
  void logCrash(
    String from,
    Object error,
    StackTrace? stack, {
    bool fatal = true,
    String? message,
  }) {}

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      data:
          nextResponseData ?? {'err': false, 'data': [], 'message': 'success'},
      statusCode: nextStatusCode,
    );
  }
}

void main() {
  late MockApiClient mockApiClient;
  late AuthProvider authProvider;
  late HomeAssignmentProvider homeAssignmentProvider;

  setUp(() {
    mockApiClient = MockApiClient();
    authProvider = AuthProvider(mockApiClient);
    homeAssignmentProvider = HomeAssignmentProvider(mockApiClient);
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<HomeAssignmentProvider>.value(
          value: homeAssignmentProvider,
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('LeavesPage Widget Test', () {
    testWidgets('renders title and sub actions correctly', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LeavesPage()));

      expect(find.text('Leaves'), findsOneWidget);
      expect(find.text('Leave Balance'), findsOneWidget);
      expect(find.text('Leave Request'), findsOneWidget);
      expect(find.text('Leaves Applied'), findsOneWidget);
    });
  });

  group('HomeAssignmentsPage Widget Test', () {
    testWidgets('renders title, filter headers, and empty state correctly', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const HomeAssignmentsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Home Assignments'), findsOneWidget);
      expect(find.text('New Homework'), findsOneWidget);
      expect(
        find.text('No Home Assignments found for selected date and class.'),
        findsOneWidget,
      );
    });

    testWidgets('renders home assignments cards correctly when populated', (
      tester,
    ) async {
      authProvider.assignedEntityClasses = [
        AssignedEntityClass(
          standard: 'Grade 8',
          classId: 6167,
          sections: ['A'],
        ),
      ];
      homeAssignmentProvider.selectedClassId = 6167;
      homeAssignmentProvider.selectedStandard = 'Grade 8';
      homeAssignmentProvider.selectedSection = 'A';

      mockApiClient.nextResponseData = {
        'err': false,
        'message': 'success',
        'metadata': {'total': 1, 'page': 1, 'pagesize': 10},
        'data': [
          {
            'Section': 'A',
            'Standard': 'Grade 8',
            'NumberOfStudents': 14,
            'HomeWorkDate': '09/12/2026',
            'Subject': 'Science',
            'Work': 'Complete questions 1 to 5 from chapter 4',
            'SubmissionDate': '09/12/2026',
            'Images': ['test-doc-id-123'],
          },
        ],
      };

      await tester.pumpWidget(buildTestableWidget(const HomeAssignmentsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Grade 8 • Sec A'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(
        find.text('Complete questions 1 to 5 from chapter 4'),
        findsOneWidget,
      );
      expect(find.text('Due: 09/12/2026'), findsOneWidget);
      expect(find.text('14 Students'), findsOneWidget);
      expect(find.text('1 Attachment'), findsOneWidget);
    });
  });

  group('CreateHomeAssignmentPage Widget Test', () {
    testWidgets('renders create form fields correctly', (tester) async {
      authProvider.assignedEntityClasses = [
        AssignedEntityClass(
          standard: 'Grade 6',
          classId: 6165,
          sections: ['A', 'B'],
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          const CreateHomeAssignmentPage(
            initialClassId: 6165,
            initialSection: 'A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Home Assignment'), findsOneWidget);
      expect(find.text('Target & Schedule'), findsOneWidget);
      expect(find.text('Homework Content'), findsOneWidget);
      expect(find.text('Attachments'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('PDF / Files'), findsOneWidget);
      expect(find.text('Publish Assignment'), findsOneWidget);
    });

    testWidgets('validates file upload as mandatory before submission', (
      tester,
    ) async {
      authProvider.assignedEntityClasses = [
        AssignedEntityClass(
          standard: 'Grade 6',
          classId: 6165,
          sections: ['A', 'B'],
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          const CreateHomeAssignmentPage(
            initialClassId: 6165,
            initialSection: 'A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter instructions in text fields
      final textFields = find.byType(TextFormField);
      for (final field in textFields.evaluate()) {
        await tester.enterText(find.byWidget(field.widget), 'Test assignment');
      }
      await tester.pumpAndSettle();

      // Tap Publish Assignment without any files attached
      await tester.tap(find.text('Publish Assignment'));
      await tester.pumpAndSettle();

      // Should show validation error message
      expect(find.text('Please upload at least one file'), findsWidgets);
    });
  });
}
