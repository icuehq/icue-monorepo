import 'package:attendance/attendance.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

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
        'For ${ongoing.standard} - Section ${ongoing.section}\nDate: ${ongoing.attendanceDate.toDisplayDay()}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      actions: [
        IcueButton(
          label: 'Discard',
          onPressed: onDelete,
          variant: IcueButtonVariant.destructive,
        ),
        IcueButton(label: 'Resume', onPressed: onResume),
      ],
    );
  }
}
