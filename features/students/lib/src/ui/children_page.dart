import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:students/src/ui/widgets/student_details_tab.dart';

/// Profile > Children: one tab per child with school and transport details.
class ChildrenPage extends StatelessWidget {
  const ChildrenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final students = context.watch<ParentAuthProvider>().students;
    if (students.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: students.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ParentLocalizations.of(context).myChildren),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: [for (final s in students) Tab(text: s.name)],
          ),
        ),
        body: TabBarView(
          children: [for (final s in students) StudentDetailsTab(student: s)],
        ),
      ),
    );
  }
}
