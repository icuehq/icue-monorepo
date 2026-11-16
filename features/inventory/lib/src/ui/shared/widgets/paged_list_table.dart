import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/providers/list_state.dart';

/// Wide-screen [IcueTable] over a [ListState]: status filter and search are
/// Firestore queries (the state reloads); rows come from its pager.
class PagedListTable<T> extends StatelessWidget {
  const PagedListTable({
    required this.title,
    required this.state,
    required this.statuses,
    required this.columns,
    required this.rowKey,
    required this.rowLabel,
    required this.onOpen,
    required this.emptyMessage,
    this.searchHint,
    this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final ListState<T> state;
  final Map<String, String> statuses;
  final List<IcueTableColumn<T>> columns;
  final String Function(T row) rowKey;
  final String Function(T row) rowLabel;
  final void Function(T row) onOpen;
  final String emptyMessage;

  /// Null hides the search box (the list has nothing searchable by prefix).
  final String? searchHint;
  final IcueTableAction? primaryAction;
  final IcueTableAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final pager = state.pager;
    return IcueTable<T>(
      title: title,
      rows: pager.items,
      rowKey: rowKey,
      rowLabel: rowLabel,
      count: pager.total ?? pager.items.length,
      status: IcueTableStatus.pager(pager),
      onRetry: pager.retry,
      pagination: IcueTablePagination.pager(pager),
      onRowTap: onOpen,
      searchHint: searchHint ?? 'Search',
      initialSearch: state.search,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: searchHint == null ? null : state.setSearch,
      filters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final MapEntry(:key, :value) in statuses.entries)
              IcueTableFilterOption(key, value),
          ],
          value: state.status,
          onChanged: state.setStatus,
        ),
      ],
      isFiltered: state.filtered,
      onClearFilters: state.clear,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
      emptyTitle: 'No ${title.toLowerCase()}',
      emptyMessage: emptyMessage,
      columns: columns,
    );
  }
}
