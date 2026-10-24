import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/attendance/create_attendance_page.dart';
import '../pages/attendance/sdk_attendance_page.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_utils.dart';
import 'attendance_mode_dialog.dart';

class ResumeAttendanceDialog extends StatefulWidget {
  const ResumeAttendanceDialog({super.key});

  @override
  State<ResumeAttendanceDialog> createState() => _ResumeAttendanceDialogState();
}

class _ResumeAttendanceDialogState extends State<ResumeAttendanceDialog> {
  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final ongoingAttendance = attendanceProvider.ongoingAttendance;
    final provider = Provider.of<AuthProvider>(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('There is an ongoing attendance!'),
        content: Text(
          'For ${ongoingAttendance?.standard} - ${ongoingAttendance?.section}\n${ongoingAttendance?.attendanceDate.formatAsIndianDate(fallback: '')}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (ongoingAttendance == null) return;
              final targetClass = provider.assignedEntityClasses
                  .where((e) => e.classId == ongoingAttendance.classId)
                  .firstOrNull;

              if (targetClass == null) {
                attendanceProvider.deleteOngoingAttendance();
                Navigator.of(context, rootNavigator: true).pop();
                return;
              }

              Navigator.of(context, rootNavigator: true).pop();
              final mode = ongoingAttendance.attendanceMode?.toUpperCase();
              if (mode == 'FACIAL_LIVE') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SdkAttendancePage(
                      standard: targetClass,
                      section: ongoingAttendance.section,
                      initialMode: AttendanceModeOption.sdkLive,
                    ),
                  ),
                );
              } else if (mode == 'FACIAL_PHOTO') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SdkAttendancePage(
                      standard: targetClass,
                      section: ongoingAttendance.section,
                      initialMode: AttendanceModeOption.sdkPhoto,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateAttendancePage(
                      standard: targetClass,
                      section: ongoingAttendance.section,
                    ),
                  ),
                );
              }
            },
            child: const Text('Continue'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                side: BorderSide(color: Colors.red),
              ),
            ),
            onPressed: () async {
              await attendanceProvider.deleteOngoingAttendance();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
