import 'package:attendance/attendance.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_photos_section.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_student_tile.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class AttendanceConfirmationPage extends StatefulWidget {
  const AttendanceConfirmationPage({super.key});

  @override
  State<AttendanceConfirmationPage> createState() =>
      _AttendanceConfirmationPageState();
}

class _AttendanceConfirmationPageState extends State<AttendanceConfirmationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleStudent(AttendanceStudent student) async {
    final newStatus = student.isPresent ? 'Absent' : 'Present';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Attendance Status'),
        content: Text(
          'Are you sure you want to mark ${student.name} as $newStatus?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AttendanceProvider>().toggleStudentAttendance(student);
    }
  }

  Future<void> _handleSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Attendance'),
        content: const Text(
          'Are you sure you want to submit this attendance record? Once submitted, it cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final result = await attendanceProvider.submitActiveAttendance();

    if (!mounted) return;

    if (result != null && !result.err) {
      track(AppEvents.attendanceSubmitted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : 'Attendance submitted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      context.go(AppRoutes.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attendanceProvider.errorMessage ??
                'Failed to submit attendance. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final ongoing = attendanceProvider.ongoingAttendance;

    if (ongoing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('No active attendance record found.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    final presentStudents = ongoing.students.where((s) => s.isPresent).toList();
    final absentStudents = ongoing.students.where((s) => !s.isPresent).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('${ongoing.standard} - Section ${ongoing.section}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Present (${presentStudents.length})'),
            Tab(text: 'Absent (${absentStudents.length})'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: attendanceProvider.isLoading ? null : _handleSubmit,
            icon: const Icon(Icons.send_rounded),
            label: const Text(
              'Submit Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (ongoing.images != null && ongoing.images!.isNotEmpty)
            AttendancePhotosSection(images: ongoing.images!),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Present List
                presentStudents.isEmpty
                    ? Center(
                        child: Text(
                          'No students marked present.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: presentStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = presentStudents[index];
                          return AttendanceStudentTile(
                            student: student,
                            onToggle: () => _toggleStudent(student),
                          );
                        },
                      ),
                // Absent List
                absentStudents.isEmpty
                    ? Center(
                        child: Text(
                          'No students marked absent.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: absentStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = absentStudents[index];
                          return AttendanceStudentTile(
                            student: student,
                            onToggle: () => _toggleStudent(student),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
