import 'package:admin_ui/src/table/table_controls.dart';
import 'package:admin_ui/src/table/table_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resolved horizontal layout shared by header, rows and skeleton so every
/// cell lines up.
class AdminTableGridLayout<T> {
  const AdminTableGridLayout({
    required this.columns,
    required this.widths,
    required this.selectable,
    required this.hasRowActions,
    required this.actionsWidth,
  });

  final List<AdminTableColumn<T>> columns;
  final List<double> widths;
  final bool selectable;
  final bool hasRowActions;
  final double actionsWidth;

  double get totalWidth =>
      widths.fold<double>(0, (sum, width) => sum + width) +
      (selectable ? AdminTableStyle.selectColumnWidth : 0) +
      (hasRowActions ? actionsWidth : 0);

  /// Fixed columns keep [AdminTableColumn.width]; flexible ones split the
  /// leftover space by flex but never shrink below minWidth (→ h-scroll).
  static List<double> resolveWidths<T>(
    List<AdminTableColumn<T>> columns,
    double available,
  ) {
    var fixed = 0.0;
    var flexSum = 0.0;
    for (final column in columns) {
      if (column.width != null) {
        fixed += column.width!;
      } else {
        flexSum += column.flex;
      }
    }
    final leftover = (available - fixed).clamp(0.0, double.infinity);
    return [
      for (final column in columns)
        column.width ??
            (leftover * column.flex / flexSum).clamp(
              column.minWidth,
              double.infinity,
            ),
    ];
  }
}

class AdminTableCheck extends StatelessWidget {
  const AdminTableCheck({required this.value, required this.label, super.key});

  /// true, false, or null for indeterminate.
  final bool? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    final on = value != false;
    return Semantics(
      label: label,
      checked: value == true,
      mixed: value == null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: on ? tokens.accent : tokens.surface,
          borderRadius: BorderRadius.circular(4.5),
          border: Border.all(
            color: on ? tokens.accent : tokens.scheme.outline,
            width: 1.4,
          ),
        ),
        child: on
            ? Icon(
                value == null ? Icons.remove_rounded : Icons.check_rounded,
                size: 12,
                color: tokens.scheme.onPrimary,
              )
            : null,
      ),
    );
  }
}

class AdminTableRow<T> extends StatefulWidget {
  const AdminTableRow({
    required this.row,
    required this.layout,
    required this.height,
    required this.selected,
    required this.focusNode,
    required this.onFocusMove,
    required this.onToggleSelect,
    required this.onTap,
    required this.actions,
    required this.alwaysShowActions,
    required this.rowLabel,
    super.key,
  });

  final T row;
  final AdminTableGridLayout<T> layout;
  final double height;
  final bool selected;
  final FocusNode focusNode;
  final void Function(int delta) onFocusMove;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onTap;
  final List<AdminTableRowAction<T>> actions;
  final bool alwaysShowActions;
  final String rowLabel;

  @override
  State<AdminTableRow<T>> createState() => _AdminTableRowState<T>();
}

class _AdminTableRowState<T> extends State<AdminTableRow<T>> {
  bool _hover = false;
  bool _focusWithin = false;
  final _menu = MenuController();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onFocusMove(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onFocusMove(-1);
      return KeyEventResult.handled;
    }
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.space && widget.onToggleSelect != null) {
      widget.onToggleSelect!();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        widget.onTap != null) {
      widget.onTap!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    final layout = widget.layout;
    final showMenu =
        widget.alwaysShowActions || _hover || _focusWithin || _menu.isOpen;
    final fill = widget.selected
        ? tokens.selectedFill
        : _hover || _focusWithin
        ? tokens.hoverFill
        : tokens.surface;
    final menuActions = [
      for (final action in widget.actions)
        if (!action.inline) action,
    ];

    return Semantics(
      container: true,
      selected: widget.selected,
      label: widget.rowLabel,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focusWithin = focused),
        onKeyEvent: _onKey,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: fill,
                border: Border(bottom: BorderSide(color: tokens.divider)),
              ),
              foregroundDecoration: widget.focusNode.hasPrimaryFocus
                  ? BoxDecoration(
                      border: Border.all(color: tokens.accent, width: 1.5),
                    )
                  : null,
              child: Stack(
                children: [
                  Row(
                    children: [
                      if (layout.selectable)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onToggleSelect,
                          child: SizedBox(
                            width: AdminTableStyle.selectColumnWidth,
                            child: Center(
                              child: AdminTableCheck(
                                value: widget.selected,
                                label: 'Select ${widget.rowLabel}',
                              ),
                            ),
                          ),
                        ),
                      for (var i = 0; i < layout.columns.length; i++)
                        SizedBox(
                          width: layout.widths[i],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AdminTableStyle.cellPadding,
                            ),
                            child: Align(
                              alignment: layout.columns[i].alignment,
                              child: layout.columns[i].cellBuilder(
                                context,
                                widget.row,
                              ),
                            ),
                          ),
                        ),
                      if (layout.hasRowActions)
                        SizedBox(
                          width: layout.actionsWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (final action in widget.actions)
                                if (action.inline)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: AdminTableIconButton(
                                      icon: action.icon,
                                      tooltip: action.label,
                                      color: action.destructive
                                          ? tokens.scheme.error
                                          : tokens.ink,
                                      onTap: () => action.onPressed(widget.row),
                                    ),
                                  ),
                              if (menuActions.isNotEmpty)
                                Opacity(
                                  opacity: showMenu ? 1 : 0,
                                  child: _RowMenu<T>(
                                    controller: _menu,
                                    row: widget.row,
                                    actions: menuActions,
                                    onOpenChanged: () => setState(() {}),
                                  ),
                                ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Accent rail marks the selected or keyboard-focused row.
                  if (widget.selected || _focusWithin)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: 3,
                        child: ColoredBox(color: tokens.accent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowMenu<T> extends StatelessWidget {
  const _RowMenu({
    required this.controller,
    required this.row,
    required this.actions,
    required this.onOpenChanged,
  });

  final MenuController controller;
  final T row;
  final List<AdminTableRowAction<T>> actions;
  final VoidCallback onOpenChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: MenuAnchor(
      controller: controller,
      style: adminTableMenuStyle(context),
      onOpen: onOpenChanged,
      onClose: onOpenChanged,
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            style: adminTableMenuItemStyle(
              context,
              destructive: action.destructive,
            ),
            leadingIcon: Icon(action.icon, size: 16),
            onPressed: () => action.onPressed(row),
            child: Text(action.label),
          ),
      ],
      builder: (_, menu, _) => AdminTableIconButton(
        icon: Icons.more_horiz_rounded,
        tooltip: 'Row actions',
        onTap: () => toggleAdminTableMenu(menu),
      ),
    ),
  );
}

/// Placeholder rows shown while the first page loads.
class AdminTableSkeleton<T> extends StatefulWidget {
  const AdminTableSkeleton({
    required this.layout,
    required this.rowHeight,
    required this.rows,
    super.key,
  });

  final AdminTableGridLayout<T> layout;
  final double rowHeight;
  final int rows;

  @override
  State<AdminTableSkeleton<T>> createState() => _AdminTableSkeletonState<T>();
}

class _AdminTableSkeletonState<T> extends State<AdminTableSkeleton<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    final layout = widget.layout;
    return Semantics(
      label: 'Loading rows',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
          child: Column(
            children: [
              for (var r = 0; r < widget.rows; r++)
                Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tokens.divider)),
                  ),
                  child: Row(
                    children: [
                      if (layout.selectable)
                        const SizedBox(
                          width: AdminTableStyle.selectColumnWidth,
                        ),
                      for (var i = 0; i < layout.columns.length; i++)
                        SizedBox(
                          width: layout.widths[i],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AdminTableStyle.cellPadding,
                            ),
                            child: Align(
                              alignment: layout.columns[i].alignment,
                              child: FractionallySizedBox(
                                widthFactor: 0.4 + ((r * 3 + i * 5) % 5) * 0.12,
                                child: Container(
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color:
                                        tokens.scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (layout.hasRowActions)
                        SizedBox(width: layout.actionsWidth),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered message used for empty, no-results and error states.
class AdminTableMessage extends StatelessWidget {
  const AdminTableMessage({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.action,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? message;
  final AdminTableAction? action;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTableStyle.of(context);
    final color = tone ?? tokens.inkMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: tokens.primary),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: tokens.secondary.copyWith(color: tokens.inkMuted),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: action!.onPressed,
                    icon: Icon(action!.icon, size: 14),
                    label: Text(action!.label),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
