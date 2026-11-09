import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

/// Height / font size of an [AppButton]: 36/13, 44/14, 52/16.
enum AppButtonSize { small, medium, large }

/// Shared button. Look is fixed per [variant] and [size] (colors come from the
/// theme's [ColorScheme]); there are no per-call style overrides. A null
/// [onPressed] disables it; [isLoading] swaps the content for a spinner.
/// Safe in unbounded-width parents (AppBar actions, Rows) unless [isFullWidth].
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticLabel;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (
        scheme.primary,
        scheme.onPrimary,
        Colors.transparent,
      ),
      AppButtonVariant.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Colors.transparent,
      ),
      AppButtonVariant.outline => (
        Colors.transparent,
        scheme.onSurface,
        scheme.outline,
      ),
      AppButtonVariant.ghost => (
        Colors.transparent,
        scheme.primary,
        Colors.transparent,
      ),
      AppButtonVariant.destructive => (
        scheme.error,
        scheme.onError,
        Colors.transparent,
      ),
    };
    final (height, fontSize, iconSize, padding) = switch (size) {
      AppButtonSize.small => (36.0, 13.0, 16.0, 12.0),
      AppButtonSize.medium => (44.0, 14.0, 20.0, 16.0),
      AppButtonSize.large => (52.0, 16.0, 24.0, 20.0),
    };

    final interactive = !isLoading && onPressed != null;
    final alpha = interactive ? 1.0 : 0.5;
    Color fade(Color color) => color.withValues(alpha: color.a * alpha);
    // The spinner stays opaque so loading reads as busy, not disabled.
    final content = isLoading ? foreground : fade(foreground);
    const radius = BorderRadius.all(Radius.circular(8));

    final void Function()? handleTap = interactive
        ? () {
            HapticFeedback.lightImpact();
            FocusManager.instance.primaryFocus?.unfocus();
            onPressed?.call();
          }
        : null;

    final overrideLabel = isLoading
        ? '${semanticLabel ?? label}, loading'
        : semanticLabel;

    return Semantics(
      button: true,
      enabled: interactive,
      label: overrideLabel,
      liveRegion: isLoading,
      excludeSemantics: overrideLabel != null,
      onTap: overrideLabel != null ? handleTap : null,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          width: isFullWidth ? double.infinity : null,
          height: height,
          decoration: BoxDecoration(
            color: fade(background),
            borderRadius: radius,
            border: border == Colors.transparent
                ? null
                : Border.all(color: fade(border)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              autofocus: autofocus,
              onTap: handleTap,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Center(
                  widthFactor: isFullWidth ? null : 1,
                  child: isLoading
                      ? SizedBox.square(
                          dimension: iconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: content,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (leadingIcon != null) ...[
                              Icon(leadingIcon, size: iconSize, color: content),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: content,
                                ),
                              ),
                            ),
                            if (trailingIcon != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                trailingIcon,
                                size: iconSize,
                                color: content,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
