import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

class GatePassStudentCard extends StatelessWidget {
  const GatePassStudentCard({
    required this.student,
    required this.onIssue,
    super.key,
  });

  final StudentData student;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).primaryColor
              .withValues(alpha: 0.1),
          child: Icon(
            Icons.school_rounded,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Adm #${student.admissionNumber} • Class ${student.standard} - ${student.section}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onIssue,
          child: const Text('Issue Pass'),
        ),
      ),
    );
  }
}
