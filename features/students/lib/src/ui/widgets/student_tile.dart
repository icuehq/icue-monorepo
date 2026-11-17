import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:students/src/ui/widgets/student_avatar.dart';

/// Name and class/section of a student with an avatar and optional trailing widget.
class StudentTile extends StatelessWidget {
  const StudentTile({
    required this.student,
    this.trailing,
    this.onTap,
    super.key,
  });

  final ParentStudent student;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final classSection = student.classSection;
    return ListTile(
      leading: const StudentAvatar(),
      minTileHeight: 80,
      title: Text(
        student.name,
        style: TextStyle(
          fontSize: 20,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: classSection == null
          ? null
          : Text(
              classSection,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
