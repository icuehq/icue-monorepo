import 'dart:math' as math;

import 'package:icue_ui/src/table/icue_table_controls.dart';
import 'package:icue_ui/src/table/icue_table_models.dart';
import 'package:flutter/material.dart';

/// Pagination strip inside the table surface.
///
/// Works for offset and cursor (Firestore) paging alike: it never assumes
/// arbitrary jumps. Numbered pages appear only when [onPageSelected] is given
/// *and* [totalCount] is known; otherwise it is Previous/Next + range.
class IcueTablePagination extends StatelessWidget {
  const IcueTablePagination({
    required this.pageIndex,
    required this.pageSize,
    required this.itemCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
    this.totalCount,
    this.pageSizeOptions = const [10, 25, 50, 100],
    this.onPageSizeChanged,
    this.onPageSelected,
    this.isLoading = false,
  });

  /// Zero-based page number (for cursor paging: pages walked so far).
  final int pageIndex;
  final int pageSize;

  /// Rows actually on the current page.
  final int itemCount;
  final int? totalCount;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;

  /// Receives a zero-based page.
  final ValueChanged<int>? onPageSelected;
  final bool isLoading;

  String get _range {
    if (itemCount == 0) return totalCount == 0 ? '0 results' : 'No rows';
    final total = totalCount;
    final knownTotal = total != null && total > 0;
    final rawStart = pageIndex * pageSize + 1;
    final start = knownTotal ? math.min(rawStart, total) : rawStart;
    final rawEnd = rawStart + itemCount - 1;
    final end = knownTotal ? math.min(rawEnd, total) : rawEnd;
    final span = start >= end ? '$end' : '$start–$end';
    return total == null ? span : '$span of $total';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    final total = totalCount;
    final pages = total == null ? 0 : (total / pageSize).ceil();
    return LayoutBuilder(
      builder: (context, constraints) {
        final showNumbers =
            onPageSelected != null && pages > 1 && constraints.maxWidth >= 640;
        return Container(
          height: IcueTableStyle.paginationHeight,
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 420 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _range,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.muted.copyWith(
                    fontFeatures: tokens.numeric.fontFeatures,
                  ),
                ),
              ),
              if (onPageSizeChanged != null) ...[
                const SizedBox(width: 14),
                _PageSizeMenu(
                  value: pageSize,
                  options: pageSizeOptions,
                  onChanged: onPageSizeChanged!,
                  showLabel: constraints.maxWidth >= 420,
                ),
              ],
              const Spacer(),
              _NavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous page',
                onTap: hasPrevious && !isLoading ? onPrevious : null,
              ),
              const SizedBox(width: 4),
              if (showNumbers)
                for (final page in _window(pageIndex, pages))
                  page == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('…', style: tokens.muted),
                        )
                      : _PageNumber(
                          page: page,
                          current: page == pageIndex,
                          onTap: isLoading ? null : () => onPageSelected!(page),
                        )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    total == null
                        ? 'Page ${pageIndex + 1}'
                        : '${pageIndex + 1} / $pages',
                    style: tokens.muted,
                  ),
                ),
              const SizedBox(width: 4),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next page',
                onTap: hasNext && !isLoading ? onNext : null,
              ),
            ],
          ),
        );
      },
    );
  }

  /// First, last, and current±1; `null` marks an ellipsis.
  static List<int?> _window(int current, int pages) {
    final keep = <int>{0, pages - 1, current - 1, current, current + 1}
      ..removeWhere((page) => page < 0 || page >= pages);
    final sorted = keep.toList()..sort();
    final out = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.add(null);
      out.add(sorted[i]);
    }
    return out;
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    return IcueTableIconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: onTap,
      size: 32,
      color: tokens.ink,
      fill: onTap == null ? null : tokens.headerFill,
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({
    required this.page,
    required this.current,
    required this.onTap,
  });

  final int page;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    return IcueTablePressable(
      onTap: current ? null : onTap,
      semanticLabel: 'Page ${page + 1}',
      tooltip: current ? null : 'Go to page ${page + 1}',
      fill: current ? tokens.accent : null,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              height: 1.2,
              color: current ? tokens.scheme.onPrimary : tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSizeMenu extends StatelessWidget {
  const _PageSizeMenu({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.showLabel,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: adminTableMenuStyle(context),
    menuChildren: [
      for (final option in options)
        MenuItemButton(
          style: adminTableMenuItemStyle(context),
          leadingIcon: Icon(
            option == value ? Icons.check_rounded : null,
            size: 15,
          ),
          onPressed: () => onChanged(option),
          child: Text('$option rows'),
        ),
    ],
    builder: (_, menu, _) => IcueTableChipButton(
      label: showLabel ? 'Rows' : null,
      value: '$value',
      tooltip: 'Rows per page',
      onTap: () => toggleAdminTableMenu(menu),
    ),
  );
}
