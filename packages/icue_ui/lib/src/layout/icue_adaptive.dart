import 'package:flutter/material.dart';

/// Width thresholds shared by every adaptive screen.
abstract final class IcueBreakpoints {
  /// From here a module shows its side navigation and forms open as dialogs.
  static const double wide = 900;

  /// From here a list is drawn as a table instead of cards.
  static const double table = 720;

  /// From here card lists show two cards per row.
  static const double twoColumns = 1000;

  /// Widest content column on large monitors.
  static const double contentMaxWidth = 1200;

  /// Widest form column.
  static const double formMaxWidth = 720;
}

extension IcueBreakpointContext on BuildContext {
  bool get isWide => MediaQuery.sizeOf(this).width >= IcueBreakpoints.wide;
}

/// Keeps [child] in a centered column of at most [maxWidth] so pages do not stretch across a monitor.
class IcueCenteredBody extends StatelessWidget {
  const IcueCenteredBody({
    required this.child,
    this.maxWidth = IcueBreakpoints.contentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// One table column of an [IcueAdaptiveList].
class IcueAdaptiveColumn<T> {
  const IcueAdaptiveColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  IcueAdaptiveColumn.text(
    String label,
    String Function(T item) value, {
    int flex = 1,
    AlignmentGeometry alignment = Alignment.centerLeft,
  }) : this(
         label: label,
         flex: flex,
         alignment: alignment,
         cell: (context, item) =>
             Text(value(item), maxLines: 2, overflow: TextOverflow.ellipsis),
       );

  final String label;
  final int flex;

  /// Fixed width for cells that cannot shrink, such as action buttons (allow
  /// 48 per [IconButton], its touch-device size). Takes precedence over [flex].
  final double? width;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext context, T item) cell;

  Widget _sized(Widget child) {
    final aligned = Align(alignment: alignment, child: child);
    return width == null
        ? Expanded(flex: flex, child: aligned)
        : SizedBox(width: width, child: aligned);
  }
}

/// A table with a header row when there is room, the phone [cardBuilder] list otherwise.
///
/// [footer] (e.g. a "Load more" button) is appended in both layouts.
class IcueAdaptiveList<T> extends StatelessWidget {
  const IcueAdaptiveList({
    required this.items,
    required this.columns,
    required this.cardBuilder,
    this.onTap,
    this.footer,
    this.controller,
    this.emptyMessage = 'No items found',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.padding,
    this.fillWidth = false,
    this.maxWidth,
    super.key,
  });

  final List<T> items;
  final List<IcueAdaptiveColumn<T>> columns;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final void Function(T item)? onTap;
  final Widget? footer;

  /// Scroll controller of the list, e.g. to load more near the end.
  final ScrollController? controller;

  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final EdgeInsetsGeometry? padding;

  /// Whether the table should span full width instead of being constrained by [maxWidth].
  final bool fillWidth;

  /// Max width when [fillWidth] is false. Defaults to [IcueBreakpoints.contentMaxWidth].
  final double? maxWidth;

  Widget _buildEmptyState(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              emptyIcon,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            emptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (emptyAction != null) ...[
            const SizedBox(height: 12),
            emptyAction!,
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final extra = footer == null ? 0 : 1;
      if (constraints.maxWidth < IcueBreakpoints.table) {
        if (items.isEmpty && extra == 0) {
          return _buildEmptyState(theme);
        }
        return ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: items.length + extra,
          itemBuilder: (context, index) => index >= items.length
              ? footer!
              : cardBuilder(context, items[index]),
        );
      }

      final table = Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    for (final column in columns)
                      column._sized(
                        Text(
                          column.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty && extra == 0
                    ? _buildEmptyState(theme)
                    : ListView.separated(
                        controller: controller,
                        itemCount: items.length + extra,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          if (index >= items.length) return footer!;
                          final item = items[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onTap == null ? null : () => onTap!(item),
                              hoverColor: theme.colorScheme.primary.withValues(
                                alpha: 0.035,
                              ),
                              splashColor: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    for (final column in columns)
                                      column._sized(column.cell(context, item)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );

      if (fillWidth) return table;
      return IcueCenteredBody(
        maxWidth: maxWidth ?? IcueBreakpoints.contentMaxWidth,
        child: table,
      );
    },
  );
}

/// A card list that shows two cards per row once there is room, one per row otherwise.
///
/// Drop-in for `ListView.builder` / `ListView.separated`: [spacing] is the gap between cards.
class IcueAdaptiveCardList extends StatelessWidget {
  const IcueAdaptiveCardList({
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.spacing = 0,
    this.controller,
    this.footer,
    this.emptyMessage = 'No items found',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final ScrollController? controller;

  /// Full-width row after the last card (e.g. "Load more").
  final Widget? footer;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (emptyAction != null) ...[
                const SizedBox(height: 12),
                emptyAction!,
              ],
            ],
          ),
        ),
      );
    }

    final extra = footer == null ? 0 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < IcueBreakpoints.twoColumns) {
          return ListView.separated(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            itemCount: itemCount + extra,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: (context, index) =>
                index == itemCount ? footer! : itemBuilder(context, index),
          );
        }
        final rows = (itemCount + 1) ~/ 2;
        return ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: rows + extra,
          itemBuilder: (context, row) {
            if (row == rows) return footer!;
            final first = row * 2;
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: itemBuilder(context, first)),
                  SizedBox(width: spacing == 0 ? 8 : spacing),
                  Expanded(
                    child: first + 1 < itemCount
                        ? itemBuilder(context, first + 1)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
