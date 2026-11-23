import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:students/src/ui/routing/students_routes.dart';
import 'package:students/src/ui/widgets/student_tile.dart';

/// Selected student on the home screen, with a switch button for siblings.
class StudentHomeCard extends StatelessWidget {
  const StudentHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ParentAuthProvider>();
    final student = auth.selectedStudent;
    if (student == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: StudentTile(
        student: student,
        trailing: auth.students.length == 1
            ? null
            : IcueButton(
                label: ParentLocalizations.of(context).switchChild,
                leadingIcon: Icons.person,
                onPressed: () =>
                    context.push(StudentsRoutes.studentsList, extra: true),
              ),
      ),
    );
  }
}
