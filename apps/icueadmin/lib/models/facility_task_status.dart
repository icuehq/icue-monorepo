import 'package:flutter/material.dart';

/// Standardized status enum for facility cleaning tasks
enum FacilityTaskStatus {
  pending('Pending', Color(0xFFD97706), Icons.schedule),
  inProgress('In Progress', Color(0xFF2563EB), Icons.pending_actions),
  completed('Completed', Color(0xFF10B981), Icons.check_circle),
  skipped('Skipped', Color(0xFFEA580C), Icons.skip_next),
  failed('Failed', Color(0xFFDC2626), Icons.cancel);

  const FacilityTaskStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  bool get isPending => this == FacilityTaskStatus.pending;
  bool get isInProgress => this == FacilityTaskStatus.inProgress;
  bool get isCompleted => this == FacilityTaskStatus.completed;
  bool get isSkipped => this == FacilityTaskStatus.skipped;
  bool get isFailed => this == FacilityTaskStatus.failed;

  /// Parse case-insensitively from any API response or status string
  static FacilityTaskStatus fromString(String? raw) {
    if (raw == null) return FacilityTaskStatus.pending;
    final s = raw.trim().toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    if (s == 'inprogress') return FacilityTaskStatus.inProgress;
    if (s == 'completed') return FacilityTaskStatus.completed;
    if (s == 'skipped') return FacilityTaskStatus.skipped;
    if (s == 'failed') return FacilityTaskStatus.failed;
    return FacilityTaskStatus.pending;
  }
}
