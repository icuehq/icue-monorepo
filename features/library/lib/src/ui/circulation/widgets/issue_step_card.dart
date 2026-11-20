import 'package:flutter/material.dart';

/// Card for one step of the issue flow: numbered badge, title, subtitle and an
/// optional trailing chip. Matches the soft card look of [IcueFormSectionCard].
class IssueStepCard extends StatelessWidget {
  const IssueStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.active = true,
    super.key,
  });

  final int step;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  /// A dimmed badge tells the user this step is waiting on the previous one.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: active
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    '$step',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: active
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
