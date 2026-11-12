import 'package:icue_firebase/icue_firebase.dart' show FirestorePager;
import 'package:flutter/material.dart';

/// Row/header sizing preset, chosen from the display menu.
enum IcueTableDensity {
  compact(rowHeight: 34, headerHeight: 30, label: 'Compact'),
  comfortable(rowHeight: 46, headerHeight: 34, label: 'Comfortable'),
  spacious(rowHeight: 56, headerHeight: 38, label: 'Spacious');

  const IcueTableDensity({
    required this.rowHeight,
    required this.headerHeight,
    required this.label,
  });

  final double rowHeight;
  final double headerHeight;
  final String label;
}

enum IcueTableStatus {
  ready,
  loading,
  error;

  /// Error wins over loading; a table that is neither is ready.
  static IcueTableStatus of({required bool failed, required bool loading}) =>
      failed
      ? error
      : loading
      ? IcueTableStatus.loading
      : ready;

  /// Failed wins; loading only while there are no rows to keep showing.
  static IcueTableStatus pager(FirestorePager<Object?> pager) => of(
    failed: pager.error != null,
    loading: pager.loading && pager.items.isEmpty,
  );
}

/// Current sort. `null` on the table means "unsorted / source order".
@immutable
class IcueTableSort {
  const IcueTableSort(this.columnId, {this.ascending = true});

  final String columnId;
  final bool ascending;

  @override
  bool operator ==(Object other) =>
      other is IcueTableSort &&
      other.columnId == columnId &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(columnId, ascending);
}

/// Column definition. Width is either fixed ([width]) or flexible
/// ([flex] share of the leftover space, never below [minWidth]).
class IcueTableColumn<T> {
  const IcueTableColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.width,
    this.flex = 1,
    this.minWidth = 96,
    this.alignment = Alignment.centerLeft,
    this.sortable = false,
    this.comparator,
    this.tooltip,
    this.hideBelowWidth,
    this.hideable = true,
  });

  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// Fixed width in logical pixels. When null the column is flexible.
  final double? width;
  final double flex;
  final double minWidth;

  /// Use [Alignment.centerRight] for numbers and money so digits line up.
  final Alignment alignment;

  /// Shows a sort control in the header. Server-side tables handle the sort via
  /// `onSortChanged`; [comparator] is used by [IcueClientTable].
  final bool sortable;
  final Comparable<Object?> Function(T row)? comparator;
  final String? tooltip;

  /// Column is dropped automatically when the table is narrower than this.
  final double? hideBelowWidth;

  /// Whether the user can hide it from the display menu.
  final bool hideable;
}

@immutable
class IcueTableFilterOption {
  const IcueTableFilterOption(this.id, this.label);
  final String id;
  final String label;
}

/// A single-choice filter shown as a compact chip. [value] null = "All",
/// unless [allowAll] is false: then a value is always required, the menu
/// offers no "All" and clearing filters leaves it alone.
@immutable
class IcueTableFilter {
  const IcueTableFilter({
    required this.id,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allowAll = true,
  });

  final String id;
  final String label;
  final List<IcueTableFilterOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  /// Narrows the rows, so "Clear filters" resets it.
  bool get isActive => allowAll && value != null;

  String get valueLabel {
    for (final option in options) {
      if (option.id == value) return option.label;
    }
    return allowAll ? 'All' : 'Select';
  }
}

/// Toolbar button. Collapses to icon-only on narrow toolbars.
@immutable
class IcueTableAction {
  const IcueTableAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

/// Per-row action: an always-visible icon button when [inline], otherwise an
/// entry of the row's "more" menu.
@immutable
class IcueTableRowAction<T> {
  const IcueTableRowAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.inline = false,
  });

  final String label;
  final IconData icon;
  final void Function(T row) onPressed;
  final bool destructive;

  /// Keep to one or two per row.
  final bool inline;
}

/// Bulk action receives the keys of the selected rows.
@immutable
class IcueTableBulkAction {
  const IcueTableBulkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final void Function(Set<Object> selectedKeys) onPressed;
  final bool destructive;
}

/// Sizes and theme-derived colours shared by the table pieces. Public so cell
/// builders can match the table.
@immutable
class IcueTableStyle {
  const IcueTableStyle._(this.scheme, this.textTheme);

  factory IcueTableStyle.of(BuildContext context) {
    final theme = Theme.of(context);
    return IcueTableStyle._(theme.colorScheme, theme.textTheme);
  }

  final ColorScheme scheme;
  final TextTheme textTheme;

  static const double radius = 12;
  static const double cellPadding = 12;
  static const double toolbarHeight = 48;
  static const double paginationHeight = 52;
  static const double controlHeight = 36;
  static const double selectColumnWidth = 40;

  Color get surface => scheme.surface;
  Color get border => scheme.outlineVariant;
  Color get divider => scheme.outlineVariant.withValues(alpha: 0.6);
  Color get headerFill => scheme.surfaceContainerHighest.withValues(alpha: 0.6);
  Color get hoverFill => scheme.onSurface.withValues(alpha: 0.04);
  Color get selectedFill => scheme.primary.withValues(alpha: 0.08);
  Color get accent => scheme.primary;
  Color get ink => scheme.onSurface;
  Color get inkMuted => scheme.onSurfaceVariant;

  TextStyle get title => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: ink,
  );
  TextStyle get header => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.5,
    color: inkMuted,
  );
  TextStyle get primary => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: ink,
  );
  TextStyle get secondary => TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: ink,
  );
  TextStyle get muted => TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: inkMuted,
  );

  /// Tabular figures so amounts and dates line up vertically.
  TextStyle get numeric =>
      secondary.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Lets cells adapt to the active density (e.g. one-line cells when compact).
class IcueTableScope extends InheritedWidget {
  const IcueTableScope({
    required this.density,
    required super.child,
    super.key,
  });

  final IcueTableDensity density;

  static IcueTableDensity densityOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IcueTableScope>()?.density ??
      IcueTableDensity.spacious;

  @override
  bool updateShouldNotify(IcueTableScope oldWidget) =>
      density != oldWidget.density;
}

/// Single-line cell text with a tooltip carrying the full value.
class IcueTableCellText extends StatelessWidget {
  const IcueTableCellText(
    this.text, {
    super.key,
    this.style,
    this.subtitle,
    this.leading,
  });

  final String text;
  final TextStyle? style;

  /// Optional muted second line (e.g. email under a name).
  final String? subtitle;

  /// Small widget before the first line only, so the subtitle stays aligned.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    final line = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? tokens.primary,
    );
    final main = leading == null
        ? line
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading!,
              const SizedBox(width: 6),
              Flexible(child: line),
            ],
          );
    final detail = subtitle == null
        ? null
        : Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.muted,
          );
    final compact =
        IcueTableScope.densityOf(context) == IcueTableDensity.compact;
    return Tooltip(
      message: subtitle == null ? text : '$text\n$subtitle',
      waitDuration: const Duration(milliseconds: 600),
      child: detail == null
          ? main
          : compact
          // Two lines don't fit a compact row: put the detail beside the name.
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: main),
                const SizedBox(width: 8),
                Flexible(flex: 2, child: detail),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [main, detail],
            ),
    );
  }
}
