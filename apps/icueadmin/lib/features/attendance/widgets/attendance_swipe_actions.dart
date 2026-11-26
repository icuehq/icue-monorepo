import 'package:flutter/material.dart';

class AttendanceSwipeActions extends StatelessWidget {
  const AttendanceSwipeActions({
    required this.onAbsent,
    required this.onPresent,
    this.onUndo,
    super.key,
  });

  final VoidCallback onAbsent;
  final VoidCallback onPresent;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            color: Colors.red,
            label: 'Absent',
            onTap: onAbsent,
          ),
          if (onUndo != null)
            _ActionButton(
              icon: Icons.replay_rounded,
              color: Colors.amber.shade800,
              label: 'Undo',
              size: 48,
              onTap: onUndo!,
            ),
          _ActionButton(
            icon: Icons.check_rounded,
            color: Colors.green,
            label: 'Present',
            onTap: onPresent,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.size = 64,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          shape: const CircleBorder(),
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: size * 0.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
