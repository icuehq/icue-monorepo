import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Placeholder layout shown while the Inventory overview figures are loading.
class OverviewSkeleton extends StatelessWidget {
  const OverviewSkeleton({required this.horizontal, super.key});

  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.45,
    );

    Widget panel({required double height}) => Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IcueSkeletonBox(width: 36, height: 36, radius: 10),
              SizedBox(width: 12),
              IcueSkeletonBox(width: 160, height: 16),
            ],
          ),
          SizedBox(height: 20),
          IcueSkeletonBox(height: 54, radius: 10),
          SizedBox(height: 10),
          IcueSkeletonBox(height: 54, radius: 10),
        ],
      ),
    );

    return IcueSkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = (constraints.maxWidth / 170).floor().clamp(2, 5);
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var index = 0; index < 5; index++)
                    Container(
                      width: width,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: IcueSkeletonBox(width: 84)),
                              SizedBox(width: 8),
                              IcueSkeletonBox(width: 30, height: 30, radius: 8),
                            ],
                          ),
                          SizedBox(height: 10),
                          IcueSkeletonBox(width: 64, height: 22),
                          SizedBox(height: 14),
                          IcueSkeletonBox(width: 92, height: 10),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (horizontal)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: panel(height: 240)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: panel(height: 240)),
              ],
            )
          else ...[
            panel(height: 200),
            const SizedBox(height: 16),
            panel(height: 200),
          ],
        ],
      ),
    );
  }
}
