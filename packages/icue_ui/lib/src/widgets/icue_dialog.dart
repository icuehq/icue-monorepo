import 'package:flutter/material.dart';
import 'package:icue_ui/src/widgets/icue_button.dart';

/// Maximum width of an [IcueDialog]: 360, 480, 600 or 760.
enum IcueDialogSize {
  small(360),
  medium(480),
  large(600),
  extraLarge(760);

  const IcueDialogSize(this.maxWidth);
  final double maxWidth;
}

/// A footer button of an [IcueDialog].
class IcueDialogAction {
  const IcueDialogAction({
    required this.label,
    required this.onPressed,
    this.variant = IcueButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IcueButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
}

/// Shared dialog: title (optional [icon]), [description] and/or [content],
/// and a footer with an optional [secondaryAction] left of [primaryAction].
/// The dialog sits on the root navigator, so action callbacks must close it
/// with `Navigator.of(context, rootNavigator: true).pop()`.
/// Open it with [IcueDialog.show], or [IcueDialog.confirm] for a yes/no ask.
class IcueDialog extends StatelessWidget {
  const IcueDialog({
    required this.title,
    required this.primaryAction,
    super.key,
    this.description,
    this.content,
    this.secondaryAction,
    this.size = IcueDialogSize.medium,
    this.icon,
  });

  final String title;
  final String? description;

  /// Richer body (a form) rendered below [description].
  final Widget? content;
  final IcueDialogAction primaryAction;
  final IcueDialogAction? secondaryAction;
  final IcueDialogSize size;
  final IconData? icon;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required IcueDialogAction primaryAction,
    String? description,
    Widget? content,
    IcueDialogAction? secondaryAction,
    IcueDialogSize size = IcueDialogSize.medium,
    IconData? icon,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (_) => IcueDialog(
        title: title,
        description: description,
        content: content,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
        size: size,
        icon: icon,
      ),
    );
  }

  /// Resolves to `true` only when the user taps [confirmLabel].
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await show<bool>(
      context,
      title: title,
      description: message,
      size: IcueDialogSize.small,
      secondaryAction: IcueDialogAction(
        label: 'Cancel',
        variant: IcueButtonVariant.ghost,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
      ),
      primaryAction: IcueDialogAction(
        label: confirmLabel,
        variant: destructive
            ? IcueButtonVariant.destructive
            : IcueButtonVariant.primary,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
            ),
            if (description != null || content != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description != null)
                        Text(
                          description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (description != null && content != null)
                        const SizedBox(height: 12),
                      ?content,
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (secondaryAction case final secondary?) _button(secondary),
                  _button(primaryAction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(IcueDialogAction action) => IcueButton(
    label: action.label,
    onPressed: action.onPressed,
    variant: action.variant,
    leadingIcon: action.icon,
    isLoading: action.isLoading,
  );
}
