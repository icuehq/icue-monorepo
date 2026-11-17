import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/providers/list_state.dart';

/// A phone list page over a [ListState]: search box (when [searchHint] is set), status
/// chips, cards with "Load more". Wide screens show [table] instead.
class PagedListPage<T> extends StatefulWidget {
  const PagedListPage({
    required this.title,
    required this.state,
    required this.statuses,
    required this.itemCard,
    required this.table,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyMessage,
    this.searchHint,
    this.floatingActionButton,
    this.actions,
    this.header,
    this.filterRow,
    super.key,
  });

  final String title;
  final ListState<T> state;

  /// Status value to chip label, after the implicit "All".
  final Map<String, String> statuses;
  final Widget Function(BuildContext context, T item) itemCard;
  final Widget table;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? searchHint;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  /// Replaces the search box (e.g. a scan field that calls `state.setSearch`).
  final Widget? header;

  /// Extra filter chips shown under the status chips.
  final Widget? filterRow;

  @override
  State<PagedListPage<T>> createState() => _PagedListPageState<T>();
}

class _PagedListPageState<T> extends State<PagedListPage<T>> {
  late final _searchController = TextEditingController(
    text: widget.state.search,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    widget.state.setSearch(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pager = state.pager;
    final theme = Theme.of(context);
    final status = state.status ?? 'all';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      floatingActionButton: context.isWide ? null : widget.floatingActionButton,
      body: context.isWide
          ? Padding(padding: const EdgeInsets.all(16), child: widget.table)
          : IcueCenteredBody(
              child: Column(
                children: [
                  if (widget.header != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: widget.header,
                    )
                  else if (widget.searchHint != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: widget.searchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: state.search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _search('');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                      ),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (final MapEntry(:key, :value) in {
                          'all': 'All',
                          ...widget.statuses,
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(value),
                              selected: status == key,
                              onSelected: (_) =>
                                  state.setStatus(key == 'all' ? null : key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.filterRow != null) ...[
                    const SizedBox(height: 4),
                    widget.filterRow!,
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: pager.error != null && pager.items.isEmpty
                        ? IcueEmptyState.error(
                            title: 'Could not load ${widget.title}',
                            message: '${pager.error}',
                            onAction: pager.retry,
                          )
                        : pager.loading && pager.items.isEmpty
                        ? const IcueSkeletonCardList()
                        : pager.items.isEmpty
                        ? (state.filtered
                              ? IcueEmptyState.noResults(
                                  title: 'Nothing matches',
                                  actionLabel: 'Clear filters',
                                  onAction: () {
                                    _searchController.clear();
                                    state.clear();
                                  },
                                )
                              : IcueEmptyState(
                                  icon: widget.emptyIcon,
                                  title: 'No ${widget.title.toLowerCase()}',
                                  message: widget.emptyMessage,
                                ))
                        : RefreshIndicator(
                            onRefresh: widget.onRefresh,
                            child: IcueAdaptiveCardList(
                              itemCount: pager.items.length,
                              footer: IcueLoadMoreFooter.of(pager),
                              itemBuilder: (context, index) =>
                                  widget.itemCard(context, pager.items[index]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
