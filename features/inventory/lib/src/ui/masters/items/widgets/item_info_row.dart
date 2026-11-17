import 'package:flutter/material.dart';

/// A label/value line with a leading icon and an optional helper text.
class ItemInfoRow extends StatelessWidget {
  const ItemInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (helper != null)
                Text(
                  helper!,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
