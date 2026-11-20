import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Table cell for a member: bold name and the class/section as a small pill.
/// Shared by reports, issued books and fines so they look the same.
class LibraryMemberCell extends StatelessWidget {
  const LibraryMemberCell({
    required this.name,
    this.classLabel,
    this.isEmployee = false,
    super.key,
  });

  final String name;
  final String? classLabel;

  /// Staff have no class; they get an "Employee" pill so they stand out from students.
  final bool isEmployee;

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IcueTableCellText(name, style: tokens.primary),
        if (classLabel != null && classLabel != '-') ...[
          const SizedBox(height: 4),
          IcueStatusPill(
            label: classLabel!,
            color: tokens.inkMuted,
            background: tokens.scheme.surfaceContainerHighest,
            icon: Icons.school_outlined,
            bordered: false,
          ),
        ] else if (isEmployee) ...[
          const SizedBox(height: 4),
          IcueStatusPill(
            label: 'Employee',
            color: tokens.inkMuted,
            background: tokens.scheme.surfaceContainerHighest,
            icon: Icons.badge_outlined,
            bordered: false,
          ),
        ],
      ],
    );
  }
}
