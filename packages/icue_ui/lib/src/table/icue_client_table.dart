import 'package:icue_ui/src/table/icue_table.dart';
import 'package:icue_ui/src/table/icue_table_models.dart';
import 'package:icue_ui/src/table/icue_table_pagination.dart';
import 'package:flutter/material.dart';

/// Filter whose predicate runs in memory.
class IcueClientFilter<T> {
  const IcueClientFilter({
    required this.id,
    required this.label,
    required this.options,
    required this.matches,
  });

  final String id;
  final String label;
  final List<IcueTableFilterOption> options;

  /// Does [row] satisfy the chosen option id?
  final bool Function(T row, String optionId) matches;
}

/// [IcueTable] for data already in memory: owns search, filters, sort,
/// selection and offset pagination. For server or Firestore-cursor data use
/// [IcueTable] directly and feed it one page.
class IcueClientTable<T> extends StatefulWidget {
  const IcueClientTable({
    required this.columns,
    required this.items,
    required this.rowKey,
    required this.title,
    super.key,
    this.searchText,
    this.searchHint = 'Search',
    this.filters = const [],
    this.externalFilters = const [],
    this.externalFiltersActive = false,
    this.onClearExternalFilters,
    this.selectable = false,
    this.bulkActions = const [],
    this.rowActions,
    this.onRowTap,
    this.rowLabel,
    this.primaryAction,
    this.secondaryAction,
    this.initialSort,
    this.initialPageSize = 10,
    this.pageSizeOptions = const [10, 25, 50, 100],
    this.status = IcueTableStatus.ready,
    this.errorMessage,
    this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
  });

  final List<IcueTableColumn<T>> columns;
  final List<T> items;
  final Object Function(T row) rowKey;
  final String title;

  /// Text searched by the toolbar. Null hides the search box.
  final String Function(T row)? searchText;
  final String searchHint;
  final List<IcueClientFilter<T>> filters;

  /// Filters whose value the caller owns (e.g. they reload server data).
  /// Shown in the toolbar after [filters]; [onClearExternalFilters] resets them.
  final List<IcueTableFilter> externalFilters;

  /// True when an external filter narrows the rows (some, like a period, always hold a value).
  final bool externalFiltersActive;
  final VoidCallback? onClearExternalFilters;
  final bool selectable;
  final List<IcueTableBulkAction> bulkActions;
  final List<IcueTableRowAction<T>> Function(T row)? rowActions;
  final ValueChanged<T>? onRowTap;
  final String Function(T row)? rowLabel;
  final IcueTableAction? primaryAction;
  final IcueTableAction? secondaryAction;
  final IcueTableSort? initialSort;
  final int initialPageSize;
  final List<int> pageSizeOptions;
  final IcueTableStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final IcueTableAction? emptyAction;

  @override
  State<IcueClientTable<T>> createState() => _AdminClientTableState<T>();
}

class _AdminClientTableState<T> extends State<IcueClientTable<T>> {
  String _query = '';
  final Map<String, String?> _filterValues = {};
  late IcueTableSort? _sort = widget.initialSort;
  late int _pageSize = widget.initialPageSize;
  int _page = 0;
  Set<Object> _selected = {};

  bool get _isFiltered =>
      _query.trim().isNotEmpty ||
      _filterValues.values.any((v) => v != null) ||
      widget.externalFiltersActive;

  List<T> _visible() {
    final query = _query.trim().toLowerCase();
    final searchText = widget.searchText;
    final out = widget.items.where((row) {
      if (query.isNotEmpty &&
          searchText != null &&
          !searchText(row).toLowerCase().contains(query)) {
        return false;
      }
      for (final filter in widget.filters) {
        final value = _filterValues[filter.id];
        if (value != null && !filter.matches(row, value)) return false;
      }
      return true;
    }).toList();
    final sort = _sort;
    if (sort != null) {
      final comparator = widget.columns
          .where((column) => column.id == sort.columnId)
          .firstOrNull
          ?.comparator;
      if (comparator != null) {
        out.sort((a, b) {
          final result = Comparable.compare(comparator(a), comparator(b));
          return sort.ascending ? result : -result;
        });
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final all = _visible();
    final pages = (all.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final slice = all.skip(page * _pageSize).take(_pageSize).toList();

    return IcueTable<T>(
      columns: widget.columns,
      rows: slice,
      rowKey: widget.rowKey,
      title: widget.title,
      count: all.length,
      status: widget.status,
      errorMessage: widget.errorMessage,
      onRetry: widget.onRetry,
      sort: _sort,
      onSortChanged: (sort) => setState(() {
        _sort = sort;
        _page = 0;
      }),
      selectedKeys: widget.selectable ? _selected : null,
      onSelectionChanged: widget.selectable
          ? (keys) => setState(() => _selected = keys)
          : null,
      bulkActions: widget.bulkActions,
      rowActions: widget.rowActions,
      onRowTap: widget.onRowTap,
      rowLabel: widget.rowLabel,
      searchHint: widget.searchHint,
      initialSearch: _query,
      onSearchChanged: widget.searchText == null
          ? null
          : (query) => setState(() {
              _query = query;
              _page = 0;
            }),
      filters: [
        for (final filter in widget.filters)
          IcueTableFilter(
            id: filter.id,
            label: filter.label,
            options: filter.options,
            value: _filterValues[filter.id],
            onChanged: (value) => setState(() {
              _filterValues[filter.id] = value;
              _page = 0;
            }),
          ),
        ...widget.externalFilters,
      ],
      isFiltered: _isFiltered,
      onClearFilters: () => setState(() {
        _query = '';
        _filterValues.clear();
        _page = 0;
        widget.onClearExternalFilters?.call();
      }),
      primaryAction: widget.primaryAction,
      secondaryAction: widget.secondaryAction,
      emptyTitle: widget.emptyTitle,
      emptyMessage: widget.emptyMessage,
      emptyAction: widget.emptyAction,
      pagination: IcueTablePagination(
        pageIndex: page,
        pageSize: _pageSize,
        itemCount: slice.length,
        totalCount: all.length,
        hasPrevious: page > 0,
        hasNext: page < pages - 1,
        pageSizeOptions: widget.pageSizeOptions,
        onPrevious: () => setState(() => _page = page - 1),
        onNext: () => setState(() => _page = page + 1),
        onPageSelected: (index) => setState(() => _page = index),
        onPageSizeChanged: (size) => setState(() {
          _pageSize = size;
          _page = 0;
        }),
      ),
    );
  }
}
