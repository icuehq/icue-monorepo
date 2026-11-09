import 'package:flutter/material.dart';

/// Themed primary/outlined button with an inline loading state.
class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.color,
    this.height = 48.0,
    this.borderRadius = 8.0,
    this.fontSize = 16.0,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isOutlined;

  /// Overrides the theme primary (e.g. error red for destructive actions).
  final Color? color;
  final double height;
  final double borderRadius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );
    final size = Size(double.infinity, height);
    final onTap = isLoading ? null : onPressed;
    final label = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isOutlined ? accent : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    return isOutlined
        ? OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              shape: shape,
              foregroundColor: accent,
              side: BorderSide(color: accent, width: 1.5),
              textStyle: textStyle,
            ),
            child: label,
          )
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              minimumSize: size,
              shape: shape,
              backgroundColor: accent,
              foregroundColor: Colors.white,
              textStyle: textStyle,
            ),
            child: label,
          );
  }
}
