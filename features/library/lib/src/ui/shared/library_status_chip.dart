import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// The one place a Library status (copy, loan, fine, incident, member, active flag) gets its
/// colour and icon, rendered as an [IcueStatusPill] chip.
class LibraryStatusChip extends StatelessWidget {
  const LibraryStatusChip(this.status, {this.label, super.key});

  /// Active / Inactive chip for records with an `active` flag.
  const LibraryStatusChip.active({required bool active, Key? key})
    : this(active ? 'active' : 'inactive', key: key);

  /// Raw status value, e.g. `partially_paid`; humanized unless [label] is given.
  final String status;
  final String? label;

  static (Color, IconData) _style(BuildContext context, String status) {
    final error = Theme.of(context).colorScheme.error;
    return switch (status) {
      'available' ||
      'active' ||
      'returned' ||
      'paid' ||
      'resolved' ||
      'on_time' => (Colors.green.shade700, Icons.check_circle_outline_rounded),
      'issued' || 'under_maintenance' || 'ready' => (
        Colors.blue.shade700,
        status == 'issued'
            ? Icons.menu_book_outlined
            : Icons.build_circle_outlined,
      ),
      'partially_paid' ||
      'due_today' => (Colors.orange.shade800, Icons.timelapse_rounded),
      'lost' ||
      'damaged' ||
      'open' ||
      'outstanding' ||
      'blocked' ||
      'overdue' ||
      'failed' => (error, Icons.error_outline_rounded),
      'waived' || 'withdrawn' || 'inactive' || 'cancelled' => (
        Colors.blueGrey.shade700,
        Icons.remove_circle_outline_rounded,
      ),
      _ => (Colors.grey.shade700, Icons.info_outline_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style(context, status);
    return IcueStatusPill(
      label: label ?? humanizeStatus(status),
      color: color,
      icon: icon,
    );
  }
}
