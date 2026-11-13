import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/src/providers/library_provider.dart';

/// One muted line for list cards: class, admission number and an optional date, e.g. `Class 5 A · Adm. 1234 · 05/03/2025`.
class MemberDetailsLine extends StatelessWidget {
  const MemberDetailsLine({
    this.classId,
    this.section,
    this.admissionNumber,
    this.isEmployee = false,
    this.date,
    super.key,
  });

  final int? classId;
  final String? section;
  final String? admissionNumber;
  final bool isEmployee;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (classId != null)
        context.watch<LibraryProvider>().classLabel(classId, section),
      if (isEmployee) 'Employee',
      if (admissionNumber?.isNotEmpty ?? false)
        '${isEmployee ? 'Staff no.' : 'Adm.'} $admissionNumber',
      ?date,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
