import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_swipe_actions.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_swipe_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class CreateAttendancePage extends StatefulWidget {
  const CreateAttendancePage({
    required this.standard,
    required this.section,
    super.key,
  });

  final AssignedEntityClass standard;
  final String section;

  @override
  State<CreateAttendancePage> createState() => _CreateAttendancePageState();
}

class _CreateAttendancePageState extends State<CreateAttendancePage> {
  int _currentIndex = 0;
  bool _isLoading = true;
  List<StudentData> _students = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final routesProvider = context.read<RoutesProvider>();

    await routesProvider.fetchStudents(
      widget.standard.classId,
      [widget.section],
    );

    if (!mounted) return;
    final studentList = routesProvider.students;

    // Check if session has previously marked students
    final attendanceProvider = context.read<AttendanceProvider>();
    final ongoing = attendanceProvider.ongoingAttendance;
    var startingIndex = 0;

    if (ongoing != null &&
        ongoing.classId == widget.standard.classId &&
        ongoing.section == widget.section) {
      final markedIds = ongoing.students.map((e) => e.id).toSet();
      final nextUnmarked =
          studentList.indexWhere((s) => !markedIds.contains(s.id));
      if (nextUnmarked != -1) {
        startingIndex = nextUnmarked;
      } else if (markedIds.length >= studentList.length &&
          studentList.isNotEmpty) {
        startingIndex = studentList.length;
      }
    }

    setState(() {
      _students = studentList;
      _currentIndex = startingIndex;
      _isLoading = false;
    });

    if (startingIndex >= studentList.length && studentList.isNotEmpty) {
      _navigateToConfirmation();
    }
  }

  Future<void> _markStudent({required bool isPresent}) async {
    if (_currentIndex >= _students.length) return;

    final student = _students[_currentIndex];
    final attendanceStudent = AttendanceStudent(
      id: student.id,
      name: student.name,
      rollNo: student.rollNo,
      admissionNumber: student.admissionNumber,
      isPresent: isPresent,
      attendanceMode: 'MANUAL',
    );

    await context.read<AttendanceProvider>().updateAttendance(
          classId: widget.standard.classId,
          className: widget.standard.standard,
          section: widget.section,
          period: '',
          student: attendanceStudent,
        );

    if (!mounted) return;

    if (_currentIndex + 1 < _students.length) {
      setState(() => _currentIndex++);
    } else {
      _navigateToConfirmation();
    }
  }

  void _handleUndo() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _navigateToConfirmation() {
    context.push(AppRoutes.attendanceConfirmation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _students.length;
    final isComplete = _currentIndex >= total && total > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('${widget.standard.standard} - Sec ${widget.section}'),
        actions: [
          if (total > 0)
            TextButton(
              onPressed: _navigateToConfirmation,
              child: const Text('Review', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Text(
                    'No students enrolled in this section.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : Column(
                  children: [
                    // Progress Indicator
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Marking Student ${_currentIndex + 1} of $total',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${(((_currentIndex) / total) * 100).toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total > 0 ? (_currentIndex / total) : 0,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Active Card
                    if (!isComplete)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AttendanceSwipeCard(
                          student: _students[_currentIndex],
                          color: Colors.white,
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'All students reviewed!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _navigateToConfirmation,
                              child: const Text('Proceed to Confirmation'),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Bottom Actions
                    if (!isComplete)
                      AttendanceSwipeActions(
                        onAbsent: () => _markStudent(isPresent: false),
                        onPresent: () => _markStudent(isPresent: true),
                        onUndo: _currentIndex > 0 ? _handleUndo : null,
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}
