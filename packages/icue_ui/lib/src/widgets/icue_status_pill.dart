import 'package:flutter/material.dart';

/// A small rounded label for a status, tinted with [color] (or [background] when given).
///
/// [compact] is the slimmer, fully rounded variant for table cells; [bordered] outlines the
/// pill in [color]; [icon] leads the label.
class IcueStatusPill extends StatelessWidget {
  const IcueStatusPill({
    required this.label,
    required this.color,
    this.background,
    this.icon,
    this.bordered = true,
    this.compact = false,
    super.key,
  });

  final String label;
  final Color color;

  /// Fill colour; defaults to a faint tint of [color].
  final Color? background;
  final IconData? icon;
  final bool bordered;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2.5 : 3),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(compact ? 10 : 6),
      border: bordered && !compact
          ? Border.all(color: color.withValues(alpha: 0.3))
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
