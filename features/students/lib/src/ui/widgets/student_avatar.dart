import 'package:flutter/material.dart';

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({this.radius = 30, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundImage: const AssetImage(
      'packages/students/assets/student_avatar.png',
    ),
  );
}
