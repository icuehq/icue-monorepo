import 'package:admin_ui/src/table/table_models.dart';
import 'package:flutter/material.dart';

/// Hover and keyboard-focus aware tap target shared by every table control.
class AdminTablePressable extends StatefulWidget {
  const AdminTablePressable({
    required this.onTap,
    required this.child,
    super.key,
    this.tooltip,
    this.semanticLabel,
    this.radius = 8,
    this.fill,
    this.border,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? tooltip;
  final String? semanticLabel;
  final double radius;
  final Color? fill;
  final Color? border;

  @override
  State<AdminTablePressable> createState() => _AdminTablePressableState();
}

class _AdminTablePressableState extends State<AdminTablePressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    final radius = BorderRadius.circular(widget.radius);
    Widget pressable = Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: Material(
        color: widget.fill ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: _focused
              ? BorderSide(color: tokens.accent, width: 1.5)
              : widget.border == null
              ? BorderSide.none
              : BorderSide(color: widget.border!),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: radius,
          child: widget.child,
        ),
      ),
    );
    if (widget.tooltip != null) {
      pressable = Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: pressable,
      );
    }
    return pressable;
  }
}

/// Compact square icon button.
class AdminTableIconButton extends StatelessWidget {
  const AdminTableIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 28,
    this.color,
    this.fill,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? fill;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    iconSize: 16,
    tooltip: tooltip,
    onPressed: onTap,
    color: color ?? AdminTableStyle.of(context).inkMuted,
    style: IconButton.styleFrom(
      fixedSize: Size.square(size),
      minimumSize: Size.square(size),
      padding: EdgeInsets.zero,
      backgroundColor: fill,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Outlined chip-button used for filters, page size and display options.
/// Pass it as the `builder` child of a [MenuAnchor].
class AdminTableChipButton extends StatelessWidget {
  const AdminTableChipButton({
    required this.onTap,
    super.key,
    this.label,
    this.value,
    this.icon,
    this.trailingChevron = true,
    this.active = false,
    this.tooltip,
  });

  final VoidCallback? onTap;
  final String? label;
  final String? value;
  final IconData? icon;
  final bool trailingChevron;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    TextStyle text(Color color, {bool bold = false}) => TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      height: 1.2,
      color: color,
    );
    return AdminTablePressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: [label, value].whereType<String>().join(' '),
      fill: active ? tokens.selectedFill : tokens.surface,
      border: active ? tokens.accent : tokens.border,
      child: SizedBox(
        height: AdminTableStyle.controlHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: tokens.inkMuted),
                if (label != null || value != null) const SizedBox(width: 5),
              ],
              if (label != null) Text(label!, style: text(tokens.inkMuted)),
              if (label != null && value != null) const SizedBox(width: 4),
              if (value != null)
                Text(value!, style: text(tokens.ink, bold: true)),
              if (trailingChevron) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.expand_more_rounded,
                  size: 15,
                  color: tokens.inkMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact menu style shared by every table menu.
MenuStyle adminTableMenuStyle(BuildContext context) {
  final tokens = AdminTableStyle.of(context);
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(tokens.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(6),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.border),
      ),
    ),
  );
}

ButtonStyle adminTableMenuItemStyle(
  BuildContext context, {
  bool destructive = false,
}) {
  final tokens = AdminTableStyle.of(context);
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(150, 34)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
    ),
    foregroundColor: WidgetStatePropertyAll(
      destructive ? tokens.scheme.error : tokens.ink,
    ),
    iconColor: WidgetStatePropertyAll(
      destructive ? tokens.scheme.error : tokens.inkMuted,
    ),
  );
}

/// Opens or closes a [MenuAnchor] from its controller.
void toggleAdminTableMenu(MenuController controller) =>
    controller.isOpen ? controller.close() : controller.open();
