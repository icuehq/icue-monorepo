import 'package:flutter/material.dart';

/// White bordered card used across the screens.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(16.0),
    this.borderColor,
    this.color,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? color;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
