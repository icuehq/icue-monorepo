import 'package:attendance/attendance.dart';
import 'package:flutter/material.dart';

class AttendanceStudentTile extends StatelessWidget {
  const AttendanceStudentTile({
    required this.student,
    required this.onToggle,
    super.key,
  });

  final AttendanceStudent student;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isPresent = student.isPresent;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isPresent
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.red.withValues(alpha: 0.15),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          'Roll #${student.rollNo} • Adm: ${student.admissionNumber}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPresent
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isPresent ? Colors.green : Colors.red),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isPresent
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  isPresent ? 'PRESENT' : 'ABSENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPresent
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
