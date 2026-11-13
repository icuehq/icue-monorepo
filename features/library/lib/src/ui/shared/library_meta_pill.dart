import 'package:flutter/material.dart';

enum LibraryPillTone { neutral, primary, error }

/// A small icon + text chip for the facts under a card's title.
class LibraryMetaPill extends StatelessWidget {
  const LibraryMetaPill(
    this.icon,
    this.text, {
    super.key,
    this.tone = LibraryPillTone.neutral,
  });

  final IconData icon;
  final String text;
  final LibraryPillTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (color, background) = switch (tone) {
      LibraryPillTone.primary => (
        colorScheme.primary,
        colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      LibraryPillTone.error => (
        colorScheme.error,
        colorScheme.errorContainer.withValues(alpha: 0.3),
      ),
      LibraryPillTone.neutral => (
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
