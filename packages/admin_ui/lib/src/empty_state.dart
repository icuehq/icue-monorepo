import 'package:flutter/material.dart';

/// A centred icon, title, optional message and optional action, for lists with nothing to show.
///
/// [neutral] greys the icon for "no results" screens; otherwise it uses the primary colour.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.outlinedAction = false,
    this.neutral = false,
    super.key,
  });

  /// "Nothing matches the search or filters", with a clear button.
  const EmptyState.noResults({
    required this.title,
    required this.onAction,
    this.message,
    this.actionLabel = 'Clear search',
    super.key,
  }) : icon = Icons.search_off_rounded,
       actionIcon = Icons.clear_rounded,
       outlinedAction = true,
       neutral = true;

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool outlinedAction;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = neutral ? scheme.onSurfaceVariant : scheme.primary;
    final label = actionLabel;
    final action = onAction;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: neutral ? 0.08 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: tone),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (label != null && action != null) ...[
                const SizedBox(height: 20),
                if (outlinedAction)
                  OutlinedButton.icon(
                    onPressed: action,
                    icon: Icon(actionIcon, size: 18),
                    label: Text(label),
                  )
                else
                  FilledButton.icon(
                    onPressed: action,
                    icon: Icon(actionIcon, size: 18),
                    label: Text(label),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
