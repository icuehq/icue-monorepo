import 'package:flutter/material.dart';

/// The bordered, tappable card every list row uses on phones.
class LibraryRecordCard extends StatelessWidget {
  const LibraryRecordCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = 14,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double padding;

  /// Defaults to the surface colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: color ?? colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}
