import 'package:icue_ui/src/table/icue_table_controls.dart';
import 'package:icue_ui/src/table/icue_table_models.dart';
import 'package:flutter/material.dart';

/// Column header: label, sort arrow and tooltip.
class IcueTableHeaderCell<T> extends StatefulWidget {
  const IcueTableHeaderCell({
    required this.column,
    required this.sort,
    required this.onSort,
    super.key,
  });

  final IcueTableColumn<T> column;
  final IcueTableSort? sort;
  final VoidCallback? onSort;

  @override
  State<IcueTableHeaderCell<T>> createState() => IcueTableHeaderCellState<T>();
}

class IcueTableHeaderCellState<T> extends State<IcueTableHeaderCell<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    final column = widget.column;
    final active = widget.sort?.columnId == column.id ? widget.sort : null;
    final sortable = column.sortable && widget.onSort != null;
    final rightAligned = column.alignment.x > 0;

    final label = Text(
      column.label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tokens.header.copyWith(
        color: active != null ? tokens.ink : tokens.inkMuted,
      ),
    );
    final arrow = sortable
        ? AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: active != null ? 1 : (_hover ? 0.5 : 0),
            child: Icon(
              active != null && !active.ascending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 13,
              color: tokens.ink,
            ),
          )
        : null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrow != null && rightAligned) ...[arrow, const SizedBox(width: 3)],
        Flexible(child: label),
        if (arrow != null && !rightAligned) ...[
          const SizedBox(width: 3),
          arrow,
        ],
      ],
    );

    Widget cell = Align(
      alignment: column.alignment,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: sortable ? 4 : IcueTableStyle.cellPadding,
        ),
        child: sortable
            ? IcueTablePressable(
                onTap: widget.onSort,
                radius: 6,
                semanticLabel: active == null
                    ? 'Sort by ${column.label}'
                    : '${column.label}, sorted ${active.ascending ? 'ascending' : 'descending'}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: content,
                ),
              )
            : content,
      ),
    );
    final tip = column.tooltip ?? (sortable ? 'Sort by ${column.label}' : null);
    if (tip != null) {
      cell = Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 600),
        child: cell,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: cell,
    );
  }
}
