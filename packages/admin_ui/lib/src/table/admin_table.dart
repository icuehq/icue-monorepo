import 'package:admin_ui/src/table/table_controls.dart';
import 'package:admin_ui/src/table/table_header_cell.dart';
import 'package:admin_ui/src/table/table_models.dart';
import 'package:admin_ui/src/table/table_pagination.dart';
import 'package:admin_ui/src/table/table_parts.dart';
import 'package:admin_ui/src/table/table_toolbar.dart';
import 'package:flutter/material.dart';

/// Table workspace: toolbar, sticky header, rows and pagination in one
/// bordered surface. Purely presentational — it renders the [rows] it is given
/// and reports intent (sort, select, page, search) through callbacks, so the
/// same widget serves in-memory data ([AdminClientTable]) and Firestore-cursor
/// data.
///
/// Sort, selection and pagination are controlled by the caller. Density and
/// hidden columns are display preferences the table owns.
///
/// With a bounded height the body scrolls under the sticky header; otherwise
/// the table sizes to its rows.
class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    required this.columns,
    required this.rows,
    required this.rowKey,
    required this.title,
    super.key,
    this.count,
    this.countLabel,
    this.status = AdminTableStatus.ready,
    this.errorMessage,
    this.onRetry,
    this.sort,
    this.onSortChanged,
    this.selectedKeys,
    this.onSelectionChanged,
    this.bulkActions = const [],
    this.rowActions,
    this.onRowTap,
    this.rowLabel,
    this.searchHint = 'Search',
    this.initialSearch = '',
    this.onSearchChanged,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.filters = const [],
    this.isFiltered = false,
    this.onClearFilters,
    this.primaryAction,
    this.secondaryAction,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
    this.pagination,
    this.initialDensity = AdminTableDensity.comfortable,
    this.onDensityChanged,
    this.initiallyHiddenColumns = const {},
    this.loadingRowCount = 8,
  });

  final List<AdminTableColumn<T>> columns;
  final List<T> rows;

  /// Stable identity of a row (document id). Selection is stored by key.
  final Object Function(T row) rowKey;
  final String title;
  final int? count;
  final String? countLabel;

  final AdminTableStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;

  final AdminTableSort? sort;
  final ValueChanged<AdminTableSort?>? onSortChanged;

  /// Pass both to enable the checkbox column and bulk bar.
  final Set<Object>? selectedKeys;
  final ValueChanged<Set<Object>>? onSelectionChanged;
  final List<AdminTableBulkAction> bulkActions;

  final List<AdminTableRowAction<T>> Function(T row)? rowActions;
  final ValueChanged<T>? onRowTap;

  /// Accessible name for a row, e.g. the client name.
  final String Function(T row)? rowLabel;

  final String searchHint;
  final String initialSearch;
  final ValueChanged<String>? onSearchChanged;
  final Duration searchDebounce;
  final List<AdminTableFilter> filters;

  /// True when search/filters narrow the data: empty results then read as
  /// "no matches" rather than "nothing here yet".
  final bool isFiltered;
  final VoidCallback? onClearFilters;
  final AdminTableAction? primaryAction;
  final AdminTableAction? secondaryAction;

  final String emptyTitle;
  final String? emptyMessage;
  final AdminTableAction? emptyAction;

  final AdminTablePagination? pagination;

  final AdminTableDensity initialDensity;
  final ValueChanged<AdminTableDensity>? onDensityChanged;
  final Set<String> initiallyHiddenColumns;
  final int loadingRowCount;

  @override
  State<AdminTable<T>> createState() => _AdminTableState<T>();
}

class _AdminTableState<T> extends State<AdminTable<T>> {
  late AdminTableDensity _density = widget.initialDensity;
  late Set<String> _hidden = {...widget.initiallyHiddenColumns};
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  final List<FocusNode> _nodes = [];

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _selectable =>
      widget.selectedKeys != null && widget.onSelectionChanged != null;

  void _syncNodes() {
    while (_nodes.length < widget.rows.length) {
      _nodes.add(FocusNode(debugLabel: 'row ${_nodes.length}'));
    }
    while (_nodes.length > widget.rows.length) {
      _nodes.removeLast().dispose();
    }
  }

  void _toggle(Object key) {
    final next = {...widget.selectedKeys!};
    next.contains(key) ? next.remove(key) : next.add(key);
    widget.onSelectionChanged!(next);
  }

  void _toggleAll(bool? current) {
    final pageKeys = widget.rows.map(widget.rowKey).toSet();
    final next = {...widget.selectedKeys!};
    current == true ? next.removeAll(pageKeys) : next.addAll(pageKeys);
    widget.onSelectionChanged!(next);
  }

  void _cycleSort(AdminTableColumn<T> column) {
    final sort = widget.sort;
    // ascending → descending → unsorted
    final next = sort?.columnId != column.id
        ? AdminTableSort(column.id)
        : sort!.ascending
        ? AdminTableSort(column.id, ascending: false)
        : null;
    widget.onSortChanged?.call(next);
  }

  void _moveFocus(int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= _nodes.length) return;
    _nodes[to].requestFocus();
    final context = _nodes[to].context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    final tokens = AdminTableStyle.of(context);
    final radius = BorderRadius.circular(AdminTableStyle.radius);
    final pagination = widget.pagination;
    final showDisplay =
        widget.status != AdminTableStatus.error &&
        (widget.rows.isNotEmpty || widget.status == AdminTableStatus.loading);
    final showPager =
        pagination != null &&
        widget.status != AdminTableStatus.error &&
        (widget.rows.isNotEmpty || pagination.hasPrevious);
    return Semantics(
      container: true,
      label: widget.title,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: tokens.surface, borderRadius: radius),
        // Painted above the children so the toolbar/header fills don't cover
        // the border where the corners curve.
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: tokens.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = constraints.hasBoundedHeight;
            final body = _body(context, tokens, constraints.maxWidth, bounded);
            return Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminTableToolbar(
                  title: widget.title,
                  count: widget.count,
                  countLabel: widget.countLabel,
                  searchHint: widget.searchHint,
                  initialSearch: widget.initialSearch,
                  onSearchChanged: widget.onSearchChanged,
                  searchDebounce: widget.searchDebounce,
                  filters: widget.filters,
                  primaryAction: widget.primaryAction,
                  secondaryAction: widget.secondaryAction,
                  density: _density,
                  onDensityChanged: showDisplay
                      ? (density) {
                          setState(() => _density = density);
                          widget.onDensityChanged?.call(density);
                        }
                      : null,
                  hideableColumns: [
                    for (final column in widget.columns)
                      if (column.hideable) column,
                  ],
                  hiddenColumnIds: _hidden,
                  onColumnToggled: showDisplay
                      ? (id) => setState(
                          () => _hidden = _hidden.contains(id)
                              ? ({..._hidden}..remove(id))
                              : {..._hidden, id},
                        )
                      : null,
                  selectedKeys: widget.selectedKeys ?? const <Object>{},
                  bulkActions: widget.bulkActions,
                  onClearSelection: () => widget.onSelectionChanged?.call({}),
                ),
                Divider(height: 1, color: tokens.border),
                bounded ? Expanded(child: body) : body,
                if (showPager) pagination,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AdminTableStyle tokens,
    double width,
    bool bounded,
  ) {
    if (widget.status == AdminTableStatus.error) {
      return _stateBox(
        bounded,
        AdminTableMessage(
          icon: Icons.error_outline_rounded,
          tone: tokens.scheme.error,
          title: "Couldn't load ${widget.title.toLowerCase()}",
          message:
              widget.errorMessage ?? 'Check your connection and try again.',
          action: widget.onRetry == null
              ? null
              : AdminTableAction(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: widget.onRetry,
                ),
        ),
      );
    }
    final loading = widget.status == AdminTableStatus.loading;
    if (!loading && widget.rows.isEmpty) {
      return _stateBox(
        bounded,
        widget.isFiltered
            ? AdminTableMessage(
                icon: Icons.search_off_rounded,
                title: 'No matching results',
                message: 'Try a different search or clear the filters.',
                action: widget.onClearFilters == null
                    ? null
                    : AdminTableAction(
                        label: 'Clear filters',
                        icon: Icons.filter_alt_off_outlined,
                        onPressed: widget.onClearFilters,
                      ),
              )
            : AdminTableMessage(
                icon: Icons.inbox_outlined,
                title: widget.emptyTitle,
                message: widget.emptyMessage,
                action: widget.emptyAction,
              ),
      );
    }

    // Columns the user hid, or that don't fit this width, drop out.
    final visible = [
      for (final column in widget.columns)
        if (!_hidden.contains(column.id) &&
            (column.hideBelowWidth == null || width >= column.hideBelowWidth!))
          column,
    ];
    final hasActions = widget.rowActions != null;
    // Width fits the widest row: icon buttons plus the hover menu.
    var inlineCount = 0;
    var hasMenu = false;
    if (hasActions) {
      for (final row in widget.rows) {
        final actions = widget.rowActions!(row);
        final inline = actions.where((action) => action.inline).length;
        if (inline > inlineCount) inlineCount = inline;
        if (actions.any((action) => !action.inline)) hasMenu = true;
      }
    }
    final actionsWidth = inlineCount * 30.0 + (hasMenu ? 28 : 0) + 12;
    final chrome =
        (_selectable ? AdminTableStyle.selectColumnWidth : 0) +
        (hasActions ? actionsWidth : 0);
    final layout = AdminTableGridLayout<T>(
      columns: visible,
      widths: AdminTableGridLayout.resolveWidths(visible, width - chrome),
      selectable: _selectable,
      hasRowActions: hasActions,
      actionsWidth: actionsWidth,
    );

    final rowsColumn = loading && widget.rows.isEmpty
        ? AdminTableSkeleton<T>(
            layout: layout,
            rowHeight: _density.rowHeight,
            rows: widget.loadingRowCount,
          )
        : _rows(layout, width < 720);

    final grid = SizedBox(
      width: layout.totalWidth,
      child: Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _header(tokens, layout, loading && widget.rows.isNotEmpty),
          if (bounded)
            Expanded(
              child: Scrollbar(
                controller: _verticalScroll,
                child: SingleChildScrollView(
                  controller: _verticalScroll,
                  child: rowsColumn,
                ),
              ),
            )
          else
            rowsColumn,
        ],
      ),
    );
    return AdminTableScope(
      density: _density,
      child: Scrollbar(
        controller: _horizontalScroll,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalScroll,
          scrollDirection: Axis.horizontal,
          child: grid,
        ),
      ),
    );
  }

  Widget _stateBox(bool bounded, Widget child) => bounded
      ? child
      : ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 220),
          child: child,
        );

  Widget _rows(AdminTableGridLayout<T> layout, bool alwaysShowActions) {
    final busy = widget.status == AdminTableStatus.loading;
    final selected = widget.selectedKeys ?? const <Object>{};
    return IgnorePointer(
      ignoring: busy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: busy ? 0.5 : 1,
        child: Column(
          children: [
            for (var i = 0; i < widget.rows.length; i++)
              AdminTableRow<T>(
                key: ValueKey(widget.rowKey(widget.rows[i])),
                row: widget.rows[i],
                layout: layout,
                height: _density.rowHeight,
                selected: selected.contains(widget.rowKey(widget.rows[i])),
                focusNode: _nodes[i],
                onFocusMove: (delta) => _moveFocus(i, delta),
                onToggleSelect: _selectable
                    ? () => _toggle(widget.rowKey(widget.rows[i]))
                    : null,
                onTap: widget.onRowTap == null
                    ? null
                    : () => widget.onRowTap!(widget.rows[i]),
                actions: widget.rowActions?.call(widget.rows[i]) ?? const [],
                alwaysShowActions: alwaysShowActions,
                rowLabel:
                    widget.rowLabel?.call(widget.rows[i]) ?? 'Row ${i + 1}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    AdminTableStyle tokens,
    AdminTableGridLayout<T> layout,
    bool loading,
  ) {
    final selected = widget.selectedKeys ?? const <Object>{};
    final pageKeys = widget.rows.map(widget.rowKey).toList();
    final count = pageKeys.where(selected.contains).length;
    final bool? all = count == 0
        ? false
        : count == pageKeys.length
        ? true
        : null;
    return Stack(
      children: [
        Container(
          height: _density.headerHeight,
          decoration: BoxDecoration(
            color: tokens.headerFill,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              if (layout.selectable)
                SizedBox(
                  width: AdminTableStyle.selectColumnWidth,
                  child: Center(
                    child: AdminTablePressable(
                      onTap: pageKeys.isEmpty ? null : () => _toggleAll(all),
                      tooltip: all == true ? 'Deselect page' : 'Select page',
                      radius: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AdminTableCheck(
                          value: all,
                          label: 'Select all rows on this page',
                        ),
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < layout.columns.length; i++)
                SizedBox(
                  width: layout.widths[i],
                  child: AdminTableHeaderCell<T>(
                    column: layout.columns[i],
                    sort: widget.sort,
                    onSort: widget.onSortChanged == null
                        ? null
                        : () => _cycleSort(layout.columns[i]),
                  ),
                ),
              if (layout.hasRowActions) SizedBox(width: layout.actionsWidth),
            ],
          ),
        ),
        // Thin progress line while a page loads over existing rows.
        if (loading)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: tokens.accent,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}
