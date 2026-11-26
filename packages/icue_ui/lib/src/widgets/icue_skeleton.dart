import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Sweeps a soft highlight across [child] while content loads. Wrap a whole placeholder layout in one shimmer so every box catches the same light.
class IcueSkeletonPulse extends StatefulWidget {
  const IcueSkeletonPulse({required this.child, super.key});

  final Widget child;

  @override
  State<IcueSkeletonPulse> createState() => _IcueSkeletonPulseState();
}

class _IcueSkeletonPulseState extends State<IcueSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlight = Colors.white.withValues(alpha: dark ? 0.1 : 0.65);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _sweep,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.transparent, highlight, Colors.transparent],
              stops: const [0.35, 0.5, 0.65],
              transform: _SweepTransform(_sweep.value),
            ).createShader(bounds),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Slides a gradient from fully left of the box to fully right of it as [progress] goes 0 to 1.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 3 - 1.5), 0, 0);
}

/// A grey rounded placeholder block standing in for text, an avatar or a chip.
class IcueSkeletonBox extends StatelessWidget {
  const IcueSkeletonBox({
    this.width,
    this.height = 12,
    this.radius = 6,
    this.circle = false,
    super.key,
  });

  /// Null fills the available width.
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder cards for a list that is loading its first page: avatar, two text lines and a trailing chip.
///
/// Two cards per row once there is room, like [IcueAdaptiveCardList].
class IcueSkeletonCardList extends StatelessWidget {
  const IcueSkeletonCardList({
    this.count = 6,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= IcueBreakpoints.twoColumns
          ? 2
          : 1;
      return IcueSkeletonPulse(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 0; index < count; index++)
                SizedBox(
                  width: columns == 1
                      ? double.infinity
                      : (constraints.maxWidth -
                                (padding.horizontal) -
                                12 * (columns - 1)) /
                            columns,
                  child: _SkeletonCard(seed: index),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const IcueSkeletonBox(width: 44, height: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.45 + (seed % 3) * 0.15,
                  child: const IcueSkeletonBox(height: 13),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.3 + (seed % 4) * 0.1,
                  child: const IcueSkeletonBox(height: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const IcueSkeletonBox(width: 56, height: 22, radius: 11),
        ],
      ),
    );
  }
}

/// Placeholder tiles for a grid of shortcuts or cards.
class IcueSkeletonTileGrid extends StatelessWidget {
  const IcueSkeletonTileGrid({
    this.count = 8,
    this.maxTileWidth = 220,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final int count;
  final double maxTileWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IcueSkeletonPulse(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxTileWidth,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IcueSkeletonBox(width: 44, height: 44, circle: true),
              SizedBox(height: 14),
              IcueSkeletonBox(width: 80, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred spinner with an optional caption, for pages or sections with no list shape to imitate.
class IcueLoadingState extends StatelessWidget {
  const IcueLoadingState({this.label = 'Loading…', super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = label;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (text != null) ...[
            const SizedBox(height: 14),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
