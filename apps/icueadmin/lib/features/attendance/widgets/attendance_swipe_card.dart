import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

class AttendanceSwipeCard extends StatelessWidget {
  const AttendanceSwipeCard({
    required this.student,
    required this.color,
    super.key,
  });

  final StudentData student;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = student.name.isNotEmpty
        ? student.name[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Roll #${student.rollNo}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            student.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (student.admissionNumber.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Adm: ${student.admissionNumber}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
