import 'package:flutter/material.dart';

/// Pill under an AppBar (`AppBar.bottom`) naming whose data the page shows,
/// e.g. the selected student.
class IcueContextBar extends StatelessWidget implements PreferredSizeWidget {
  const IcueContextBar({
    required this.label,
    this.icon = Icons.person_outline,
    super.key,
  });

  final String? label;
  final IconData icon;

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, color: primary, size: 20),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
