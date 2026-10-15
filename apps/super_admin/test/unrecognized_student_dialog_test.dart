import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:super_admin/ui/widgets/unrecognized_student_dialog.dart';

void main() {
  group('UnrecognizedStudentDialog', () {
    testWidgets('renders transport alert dialog with bus messaging', (
      WidgetTester tester,
    ) async {
      final record = UnrecognizedFaceRecord(
        confidenceScore: 0.42,
        timestamp: DateTime(2026, 9, 30, 10, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    UnrecognizedStudentDialog.show(
                      context: context,
                      type: AttendanceType.TRANSPORT,
                      unrecognizedFaces: [record],
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Check Transport Specific headers and texts
      expect(find.text('BUS TRANSPORT ALERT'), findsOneWidget);
      expect(
        find.text('This student does not belong to this Bus.'),
        findsOneWidget,
      );
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      expect(find.text('DETECTED FACE DETAILS'), findsOneWidget);
    });

    testWidgets('renders attendance alert dialog with classroom messaging', (
      WidgetTester tester,
    ) async {
      final record = UnrecognizedFaceRecord(
        confidenceScore: 0.35,
        timestamp: DateTime(2026, 9, 30, 9, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    UnrecognizedStudentDialog.show(
                      context: context,
                      type: AttendanceType.ATTENDANCE,
                      unrecognizedFaces: [record],
                      onAction: () {},
                      actionLabel: 'FLAG EXCEPTION',
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Check Attendance Specific headers and texts
      expect(find.text('ATTENDANCE ALERT'), findsOneWidget);
      expect(
        find.text('This student does not belong to this roster.'),
        findsOneWidget,
      );
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      expect(find.text('FLAG EXCEPTION'), findsOneWidget);
    });

    testWidgets('shows dialog when AttendanceResult has unrecognized students', (
      WidgetTester tester,
    ) async {
      final attendanceResult = AttendanceResult(
        present: [
          AttendanceRecord(
            personId: '101',
            confidenceScore: 0.95,
            timestamp: DateTime.now(),
          ),
        ],
        absentPersonIds: const [],
        unrecognizedFaceCount: 1,
        unrecognizedFaces: [
          UnrecognizedFaceRecord(
            confidenceScore: 0.38,
            timestamp: DateTime.now(),
          ),
        ],
        totalRosterCount: 1,
        sessionStartTime: DateTime.now(),
        sessionEndTime: DateTime.now(),
        mode: AttendanceMode.liveStream,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    if (attendanceResult.hasUnrecognizedFaces ||
                        attendanceResult.unrecognizedFaceCount > 0) {
                      UnrecognizedStudentDialog.show(
                        context: context,
                        type: AttendanceType.TRANSPORT,
                        attendanceResult: attendanceResult,
                      );
                    }
                  },
                  child: const Text('Process Result'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Process Result'));
      await tester.pumpAndSettle();

      expect(find.byType(UnrecognizedStudentDialog), findsOneWidget);
      expect(find.text('BUS TRANSPORT ALERT'), findsOneWidget);
    });

    testWidgets('does NOT show dialog when AttendanceResult contains only success students', (
      WidgetTester tester,
    ) async {
      final attendanceResult = AttendanceResult(
        present: [
          AttendanceRecord(
            personId: '101',
            confidenceScore: 0.95,
            timestamp: DateTime.now(),
          ),
          AttendanceRecord(
            personId: '102',
            confidenceScore: 0.92,
            timestamp: DateTime.now(),
          ),
        ],
        absentPersonIds: const [],
        unrecognizedFaceCount: 0,
        unrecognizedFaces: const [],
        totalRosterCount: 2,
        sessionStartTime: DateTime.now(),
        sessionEndTime: DateTime.now(),
        mode: AttendanceMode.liveStream,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // For success students: no dialog is shown!
                    if (attendanceResult.hasUnrecognizedFaces ||
                        attendanceResult.unrecognizedFaceCount > 0) {
                      UnrecognizedStudentDialog.show(
                        context: context,
                        type: AttendanceType.TRANSPORT,
                        attendanceResult: attendanceResult,
                      );
                    }
                  },
                  child: const Text('Process Result'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Process Result'));
      await tester.pumpAndSettle();

      expect(find.byType(UnrecognizedStudentDialog), findsNothing);
    });
  });
}
