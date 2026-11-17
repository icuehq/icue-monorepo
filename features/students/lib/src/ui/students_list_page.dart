import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:students/src/providers/parent_students_provider.dart';
import 'package:students/src/ui/widgets/student_tile.dart';

/// Child picker. Opened after login (refreshes the list) and from the home
/// card's switch button ([isSwitching], no refresh).
class StudentsListPage extends StatefulWidget {
  const StudentsListPage({this.isSwitching = false, super.key});

  final bool isSwitching;

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSwitching) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => context.read<ParentAuthProvider>().refreshStudents(),
      );
    }
  }

  Future<void> _select(ParentStudent student) async {
    final auth = context.read<ParentAuthProvider>();
    final students = context.read<ParentStudentsProvider>();
    setState(() => _selecting = true);
    students.reset();
    await auth.selectStudent(student);
    final loaded = await students.loadRoleActions(student.id);
    if (!mounted) return;
    setState(() => _selecting = false);
    if (loaded) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ParentAuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      appBar: AppBar(title: Text(ParentLocalizations.of(context).selectChild)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage(IcueAssets.authBackground),
          ),
        ),
        child: auth.busy
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: auth.students.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final student = auth.students[index];
                  return Card(
                    key: ValueKey(student.id),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: StudentTile(
                      student: student,
                      trailing:
                          _selecting && auth.selectedStudent?.id == student.id
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.arrow_forward_ios_rounded),
                      onTap: _selecting ? null : () => _select(student),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
