import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';

/// A centred icon, title, optional message and optional action, for lists with nothing to show.
///
/// [neutral] greys the icon for "no results" screens; otherwise it uses the primary colour.
class IcueEmptyState extends StatelessWidget {
  const IcueEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.outlinedAction = false,
    this.neutral = false,
    super.key,
  }) : isError = false;

  /// "Nothing matches the search or filters", with a clear button.
  const IcueEmptyState.noResults({
    required this.title,
    required this.onAction,
    this.message,
    this.actionLabel = 'Clear search',
    super.key,
  }) : icon = Icons.search_off_rounded,
       actionIcon = Icons.clear_rounded,
       outlinedAction = true,
       neutral = true,
       isError = false;

  /// "Could not load", with a retry button.
  const IcueEmptyState.error({
    required this.onAction,
    this.title = 'Something went wrong',
    this.message,
    this.actionLabel = 'Try again',
    super.key,
  }) : icon = Icons.cloud_off_rounded,
       actionIcon = Icons.refresh_rounded,
       outlinedAction = true,
       neutral = false,
       isError = true;

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool outlinedAction;
  final bool neutral;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = isError
        ? scheme.error
        : neutral
        ? scheme.onSurfaceVariant
        : scheme.primary;
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.05),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.withValues(alpha: neutral ? 0.1 : 0.12),
                  ),
                  child: Icon(icon, size: 40, color: tone),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
                  IcueButton(
                    label: label,
                    onPressed: action,
                    variant: IcueButtonVariant.outline,
                    leadingIcon: actionIcon,
                  )
                else
                  IcueButton(
                    label: label,
                    onPressed: action,
                    leadingIcon: actionIcon,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
