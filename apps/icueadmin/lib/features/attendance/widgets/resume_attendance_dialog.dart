import 'package:attendance/attendance.dart';
import 'package:flutter/material.dart';

class ResumeAttendanceDialog extends StatelessWidget {
  const ResumeAttendanceDialog({
    required this.ongoing,
    required this.onResume,
    required this.onDelete,
    super.key,
  });

  final CreateAttendance ongoing;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Ongoing Attendance Found!'),
      content: Text(
        'For ${ongoing.standard} - Section ${ongoing.section}\nDate: ${ongoing.attendanceDate}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          onPressed: onDelete,
          child: const Text('Discard'),
        ),
        FilledButton(onPressed: onResume, child: const Text('Resume')),
      ],
    );
  }
}
