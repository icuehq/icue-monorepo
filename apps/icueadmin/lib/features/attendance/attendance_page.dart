import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/attendance/widgets/attendance_ongoing_card.dart';
import 'package:icueadmin/features/attendance/widgets/resume_attendance_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.getAssignedEntities(forAttendance: true);
      if (!mounted) return;
      await context.read<AttendanceProvider>().getOngoingAttendance();
    });
  }

  void _handleResumeSession(CreateAttendance ongoing) {
    final auth = context.read<AuthProvider>();
    final targetClass = auth.assignedEntityClasses
        .where((e) => e.classId == ongoing.classId)
        .firstOrNull;

    if (targetClass != null) {
      final mode = ongoing.attendanceMode?.toUpperCase();
      if (mode == 'FACIAL_LIVE') {
        context.push(
          AppRoutes.sdkAttendance,
          extra: {
            'standard': targetClass,
            'section': ongoing.section,
            'initialMode': AttendanceModeOption.sdkLive,
          },
        );
      } else if (mode == 'FACIAL_PHOTO') {
        context.push(
          AppRoutes.sdkAttendance,
          extra: {
            'standard': targetClass,
            'section': ongoing.section,
            'initialMode': AttendanceModeOption.sdkPhoto,
          },
        );
      } else {
        context.push(
          AppRoutes.createAttendance,
          extra: {'standard': targetClass, 'section': ongoing.section},
        );
      }
    }
  }

  Future<bool> _checkAndShowOngoingDialog() async {
    final ongoing = await context
        .read<AttendanceProvider>()
        .getOngoingAttendance();
    if (!mounted || ongoing == null) return true;

    var resume = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResumeAttendanceDialog(
        ongoing: ongoing,
        onResume: () {
          resume = true;
          Navigator.of(context).pop();
        },
        onDelete: () {
          context.read<AttendanceProvider>().deleteOngoingAttendance();
          Navigator.of(context).pop();
        },
      ),
    );

    if (resume) {
      _handleResumeSession(ongoing);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final assignedClasses = auth.assignedEntityClasses;
    final ongoing = attendanceProvider.ongoingAttendance;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await context.read<AuthProvider>().getAssignedEntities(
                forAttendance: true,
              );
              if (context.mounted) {
                await context.read<AttendanceProvider>().getOngoingAttendance();
              }
            },
          ),
        ],
      ),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (ongoing != null)
                  AttendanceOngoingCard(
                    ongoing: ongoing,
                    onResume: () => _handleResumeSession(ongoing),
                    onDiscard: () => context
                        .read<AttendanceProvider>()
                        .deleteOngoingAttendance(),
                  ),
                Expanded(
                  child: assignedClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No classes assigned for attendance.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: assignedClasses.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = assignedClasses[index];

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  item.standard,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.sections.length} section(s)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.primary,
                                ),
                                onTap: () async {
                                  if (await _checkAndShowOngoingDialog()) {
                                    if (context.mounted) {
                                      await context.push(
                                        AppRoutes.attendanceSections,
                                        extra: item,
                                      );
                                      if (context.mounted) {
                                        await context
                                            .read<AttendanceProvider>()
                                            .getOngoingAttendance();
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
