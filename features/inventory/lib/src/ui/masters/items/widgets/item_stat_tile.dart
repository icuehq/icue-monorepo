import 'package:flutter/material.dart';

/// A headline figure (stock, reorder level, price) with a caption underneath.
class ItemStatTile extends StatelessWidget {
  const ItemStatTile({
    required this.label,
    required this.value,
    this.caption,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? theme.colorScheme.outlineVariant).withValues(
            alpha: 0.6,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color ?? muted,
              ),
            ),
        ],
      ),
    );
  }
}
