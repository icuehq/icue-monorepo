import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:students/src/providers/parent_students_provider.dart';
import 'package:students/src/ui/widgets/route_details_card.dart';
import 'package:students/src/ui/widgets/student_tile.dart';

class StudentDetailsTab extends StatefulWidget {
  const StudentDetailsTab({required this.student, super.key});

  final ParentStudent student;

  @override
  State<StudentDetailsTab> createState() => _StudentDetailsTabState();
}

class _StudentDetailsTabState extends State<StudentDetailsTab> {
  @override
  void initState() {
    super.initState();
    if (widget.student.isTransportOpted ?? false) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => context.read<ParentStudentsProvider>().loadRouteDetails(
          widget.student.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParentStudentsProvider>();
    final transport = widget.student.isTransportOpted ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: StudentTile(student: widget.student),
        ),
        if (provider.routeLoading)
          const Center(child: CircularProgressIndicator()),
        if (transport)
          RouteDetailsCard(details: provider.routeDetails[widget.student.id])
        else
          Text(
            ParentLocalizations.of(context).transportNotOpted,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}
