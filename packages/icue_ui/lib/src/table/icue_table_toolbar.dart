import 'dart:async';

import 'package:icue_ui/src/table/icue_table_controls.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';

/// One-row toolbar: title+count · search · filters · display · CTA.
/// Collapses by width (search → icon, filters → one menu, CTA → icon) and
/// turns into the bulk-action bar in place while rows are selected.
class IcueTableToolbar extends StatefulWidget {
  const IcueTableToolbar({
    required this.title,
    super.key,
    this.count,
    this.countLabel,
    this.searchHint = 'Search',
    this.initialSearch = '',
    this.onSearchChanged,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.filters = const [],
    this.primaryAction,
    this.secondaryAction,
    this.density = IcueTableDensity.comfortable,
    this.onDensityChanged,
    this.hideableColumns = const [],
    this.hiddenColumnIds = const {},
    this.onColumnToggled,
    this.selectedKeys = const {},
    this.bulkActions = const [],
    this.onClearSelection,
  });

  final String title;
  final int? count;

  /// Replaces the numeric badge, e.g. "25+" for cursor paging.
  final String? countLabel;
  final String searchHint;
  final String initialSearch;
  final ValueChanged<String>? onSearchChanged;
  final Duration searchDebounce;
  final List<IcueTableFilter> filters;
  final IcueTableAction? primaryAction;
  final IcueTableAction? secondaryAction;
  final IcueTableDensity density;
  final ValueChanged<IcueTableDensity>? onDensityChanged;
  final List<IcueTableColumn<dynamic>> hideableColumns;
  final Set<String> hiddenColumnIds;
  final ValueChanged<String>? onColumnToggled;
  final Set<Object> selectedKeys;
  final List<IcueTableBulkAction> bulkActions;
  final VoidCallback? onClearSelection;

  @override
  State<IcueTableToolbar> createState() => _AdminTableToolbarState();
}

class _AdminTableToolbarState extends State<IcueTableToolbar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialSearch,
  );
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _searchOpen = false; // narrow layouts only

  @override
  void didUpdateWidget(IcueTableToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent cleared the query (e.g. "Clear filters"): mirror it in the box.
    if (widget.initialSearch.isEmpty && oldWidget.initialSearch.isNotEmpty) {
      _search.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      widget.searchDebounce,
      () => widget.onSearchChanged?.call(value),
    );
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    widget.onSearchChanged?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    final bulk = widget.selectedKeys.isNotEmpty;
    return Container(
      height: IcueTableStyle.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: bulk ? tokens.selectedFill : tokens.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (bulk) return _bulkBar(tokens, width);
          final wide = width >= 900;
          final narrow = width < 600;
          if (narrow && _searchOpen) return _expandedSearch();
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: _titleBlock(tokens)),
                    const SizedBox(width: 12),
                    if (widget.onSearchChanged != null) ...[
                      if (narrow)
                        IcueTableIconButton(
                          icon: Icons.search_rounded,
                          tooltip: 'Search',
                          onTap: () {
                            setState(() => _searchOpen = true);
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _searchFocus.requestFocus(),
                            );
                          },
                        )
                      else
                        SizedBox(
                          width: wide ? 240 : 180,
                          height: IcueTableStyle.controlHeight,
                          child: _searchField(tokens),
                        ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.filters.isNotEmpty)
                      if (wide)
                        for (final filter in widget.filters) ...[
                          _FilterChip(filter: filter),
                          const SizedBox(width: 6),
                        ]
                      else ...[
                        _FilterMenu(filters: widget.filters, iconOnly: narrow),
                        const SizedBox(width: 6),
                      ],
                  ],
                ),
              ),
              if (widget.secondaryAction != null) ...[
                _Cta(
                  action: widget.secondaryAction!,
                  iconOnly: !wide,
                  quiet: true,
                ),
                const SizedBox(width: 6),
              ],
              if (widget.primaryAction != null) ...[
                _Cta(action: widget.primaryAction!, iconOnly: narrow),
                const SizedBox(width: 8),
              ],
              if (widget.onDensityChanged != null ||
                  widget.onColumnToggled != null)
                _DisplayMenu(
                  density: widget.density,
                  onDensityChanged: widget.onDensityChanged,
                  columns: widget.hideableColumns,
                  hidden: widget.hiddenColumnIds,
                  onColumnToggled: widget.onColumnToggled,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _titleBlock(IcueTableStyle tokens) {
    final badge = widget.countLabel ?? widget.count?.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.title,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.headerFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: tokens.muted.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: tokens.numeric.fontFeatures,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _searchField(IcueTableStyle tokens) => TextField(
    controller: _search,
    focusNode: _searchFocus,
    onChanged: _onChanged,
    style: tokens.secondary,
    decoration: InputDecoration(
      isDense: true,
      hintText: widget.searchHint,
      suffixIcon: _search.text.isEmpty
          ? Icon(Icons.search_rounded, size: 16, color: tokens.inkMuted)
          : IcueTableIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear search',
              size: 24,
              onTap: _clearSearch,
            ),
    ),
  );

  Widget _expandedSearch() => Row(
    children: [
      Expanded(child: _searchField(IcueTableStyle.of(context))),
      const SizedBox(width: 6),
      IcueTableIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close search',
        onTap: () => setState(() => _searchOpen = false),
      ),
    ],
  );

  Widget _bulkBar(IcueTableStyle tokens, double width) => Row(
    children: [
      IcueTableIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Clear selection',
        onTap: widget.onClearSelection,
      ),
      const SizedBox(width: 6),
      Text(
        '${widget.selectedKeys.length} selected',
        style: tokens.title.copyWith(fontSize: 14),
      ),
      const Spacer(),
      for (final action in widget.bulkActions) ...[
        const SizedBox(width: 6),
        _Cta(
          action: IcueTableAction(
            label: action.label,
            icon: action.icon,
            destructive: action.destructive,
            onPressed: () => action.onPressed(widget.selectedKeys),
          ),
          iconOnly: width < 560,
          quiet: true,
        ),
      ],
    ],
  );
}

/// Toolbar button built on [IcueButton]; an icon button when narrow.
/// [quiet] = outline variant used for secondary and bulk actions.
class _Cta extends StatelessWidget {
  const _Cta({
    required this.action,
    required this.iconOnly,
    this.quiet = false,
  });

  final IcueTableAction action;
  final bool iconOnly;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (!iconOnly) {
      return IcueButton(
        label: action.label,
        leadingIcon: action.icon,
        onPressed: action.onPressed,
        size: IcueButtonSize.small,
        variant: action.destructive
            ? IcueButtonVariant.destructive
            : quiet
            ? IcueButtonVariant.outline
            : IcueButtonVariant.primary,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(action.icon),
      iconSize: 18,
      tooltip: action.label,
      onPressed: action.onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        foregroundColor: action.destructive
            ? scheme.onError
            : quiet
            ? scheme.onSurface
            : scheme.onPrimary,
        backgroundColor: action.destructive
            ? scheme.error
            : quiet
            ? scheme.surface
            : scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: quiet && !action.destructive
              ? BorderSide(color: scheme.outline)
              : BorderSide.none,
        ),
      ),
    );
  }
}

List<Widget> _filterItems(BuildContext context, IcueTableFilter filter) => [
  if (filter.allowAll)
    MenuItemButton(
      style: adminTableMenuItemStyle(context),
      leadingIcon: Icon(
        filter.value == null ? Icons.check_rounded : null,
        size: 15,
      ),
      onPressed: () => filter.onChanged(null),
      child: const Text('All'),
    ),
  for (final option in filter.options)
    MenuItemButton(
      style: adminTableMenuItemStyle(context),
      leadingIcon: Icon(
        filter.value == option.id ? Icons.check_rounded : null,
        size: 15,
      ),
      onPressed: () => filter.onChanged(option.id),
      child: Text(option.label),
    ),
];

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.filter});
  final IcueTableFilter filter;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: adminTableMenuStyle(context),
    menuChildren: _filterItems(context, filter),
    builder: (_, menu, _) => IcueTableChipButton(
      label: filter.label,
      value: filter.valueLabel,
      active: filter.isActive,
      onTap: () => toggleAdminTableMenu(menu),
      tooltip: 'Filter by ${filter.label.toLowerCase()}',
    ),
  );
}

/// All filters behind one button (medium/narrow widths).
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.filters, required this.iconOnly});
  final List<IcueTableFilter> filters;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final active = filters.where((filter) => filter.isActive).toList();
    return MenuAnchor(
      style: adminTableMenuStyle(context),
      menuChildren: [
        for (final filter in filters)
          SubmenuButton(
            style: adminTableMenuItemStyle(context),
            menuStyle: adminTableMenuStyle(context),
            menuChildren: _filterItems(context, filter),
            child: Text('${filter.label}: ${filter.valueLabel}'),
          ),
        if (active.isNotEmpty) ...[
          const Divider(height: 8),
          MenuItemButton(
            style: adminTableMenuItemStyle(context),
            leadingIcon: const Icon(Icons.filter_alt_off_outlined, size: 15),
            onPressed: () {
              for (final filter in active) {
                filter.onChanged(null);
              }
            },
            child: const Text('Clear filters'),
          ),
        ],
      ],
      builder: (_, menu, _) => IcueTableChipButton(
        icon: Icons.filter_list_rounded,
        label: iconOnly ? null : 'Filters',
        value: active.isEmpty ? null : '${active.length}',
        trailingChevron: false,
        active: active.isNotEmpty,
        tooltip: 'Filters',
        onTap: () => toggleAdminTableMenu(menu),
      ),
    );
  }
}

class _DisplayMenu extends StatelessWidget {
  const _DisplayMenu({
    required this.density,
    required this.onDensityChanged,
    required this.columns,
    required this.hidden,
    required this.onColumnToggled,
  });

  final IcueTableDensity density;
  final ValueChanged<IcueTableDensity>? onDensityChanged;
  final List<IcueTableColumn<dynamic>> columns;
  final Set<String> hidden;
  final ValueChanged<String>? onColumnToggled;

  Widget _heading(IcueTableStyle tokens, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
    child: Text(text.toUpperCase(), style: tokens.header),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = IcueTableStyle.of(context);
    return MenuAnchor(
      style: adminTableMenuStyle(context),
      menuChildren: [
        if (onDensityChanged != null) ...[
          _heading(tokens, 'Row density'),
          for (final option in IcueTableDensity.values)
            MenuItemButton(
              style: adminTableMenuItemStyle(context),
              leadingIcon: Icon(
                option == density ? Icons.check_rounded : null,
                size: 15,
              ),
              onPressed: () => onDensityChanged!(option),
              child: Text(option.label),
            ),
        ],
        if (onColumnToggled != null && columns.isNotEmpty) ...[
          const Divider(height: 8),
          _heading(tokens, 'Columns'),
          for (final column in columns)
            CheckboxMenuButton(
              style: adminTableMenuItemStyle(context),
              closeOnActivate: false,
              value: !hidden.contains(column.id),
              onChanged: (_) => onColumnToggled!(column.id),
              child: Text(column.label),
            ),
        ],
      ],
      builder: (_, menu, _) => IcueTableIconButton(
        icon: Icons.tune_rounded,
        tooltip: 'Display options',
        onTap: () => toggleAdminTableMenu(menu),
      ),
    );
  }
}
