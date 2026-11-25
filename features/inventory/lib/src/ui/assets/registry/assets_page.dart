import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show AssetStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_cards.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_scan_dialog.dart';
import 'package:inventory/src/ui/assets/registry/widgets/assets_tables.dart';
import 'package:provider/provider.dart';

/// Asset management: the register of registered assets, and the received units still waiting to be registered.
class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage>
    with SingleTickerProviderStateMixin {
  static final _statuses = {
    for (final status in AssetStatus.values)
      if (status != AssetStatus.unregistered) status: humanizeStatus(status),
  };

  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _lastTabIndex = 0;

  bool get _registeredTab => _tabs.index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.index == _lastTabIndex) return;
    _lastTabIndex = _tabs.index;
    _debounce?.cancel();
    final activeSearch = _activeState(context.read<AssetsProvider>()).search;
    if (_searchController.text != activeSearch) {
      _searchController.text = activeSearch;
    }
    setState(() {});
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (!mounted) return;
    final assetsProvider = context.read<AssetsProvider>();
    await Future.wait([
      assetsProvider.assetList.load(),
      assetsProvider.unregisteredList.load(),
    ]);
  }

  ListState<InventoryAsset> _activeState(AssetsProvider assetsProvider) =>
      _registeredTab
      ? assetsProvider.assetList
      : assetsProvider.unregisteredList;

  /// Typing searches after a short pause: registered assets by name prefix (as written) in Firestore,
  /// unregistered ones in the loaded list.
  void _typed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _activeState(context.read<AssetsProvider>()).setSearch(value);
    });
  }

  void _submitted(String value) {
    _debounce?.cancel();
    _activeState(context.read<AssetsProvider>()).setSearch(value);
  }

  Future<void> _openScanDialog() async {
    final asset = await AssetScanDialog.show(context);
    if (asset != null && mounted) await _open(asset);
  }

  /// A registered asset opens its details; an unregistered one opens the registration form.
  Future<void> _open(InventoryAsset asset) async {
    await context.push(
      asset.isUnregistered
          ? '${InventoryRoutes.inventoryAssetForm}?id=${asset.id}'
          : '${InventoryRoutes.inventoryAssetDetails}?id=${asset.id}',
    );
    if (mounted) await _load();
  }

  Future<void> _clearAllFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    return context.read<AssetsProvider>().clearFilters();
  }

  String _storeName(InventoryProvider inventoryProvider, String id) =>
      inventoryProvider.stores
          .where((store) => store.id == id)
          .firstOrNull
          ?.name ??
      id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final wide = context.isWide;
    final assetsProvider = context.watch<AssetsProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final waitingPager = assetsProvider.unregisteredList.pager;
    final waitingCount = waitingPager.total ?? waitingPager.items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset management'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: wide,
          tabAlignment: wide ? TabAlignment.start : null,
          labelColor: foreground,
          unselectedLabelColor: foreground.withValues(alpha: 0.72),
          indicatorColor: foreground,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            const Tab(text: 'Registered'),
            Tab(
              text: waitingCount == 0
                  ? 'Unregistered'
                  : 'Unregistered ($waitingCount${waitingPager.hasNext ? '+' : ''})',
            ),
          ],
        ),
      ),
      body: wide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: _registeredTab
                  ? RegisteredAssetsTable(
                      key: const ValueKey('registered-table'),
                      assetsProvider: assetsProvider,
                      inventoryProvider: inventoryProvider,
                      statuses: _statuses,
                      storeName: (id) => _storeName(inventoryProvider, id),
                      onOpen: _open,
                      onClearFilters: _clearAllFilters,
                      onScan: _openScanDialog,
                      onRefresh: _load,
                    )
                  : UnregisteredAssetsTable(
                      key: const ValueKey('unregistered-table'),
                      assetsProvider: assetsProvider,
                      inventoryProvider: inventoryProvider,
                      storeName: (id) => _storeName(inventoryProvider, id),
                      onOpen: _open,
                      onClearFilters: _clearAllFilters,
                      onScan: _openScanDialog,
                      onRefresh: _load,
                    ),
            )
          : _mobileBody(assetsProvider, inventoryProvider),
    );
  }

  Widget _mobileBody(
    AssetsProvider assetsProvider,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);
    final activeState = _activeState(assetsProvider);
    final pager = activeState.pager;
    final rows = activeState.rows;
    final isFiltered = activeState.filtered || assetsProvider.storeId != null;
    final showStores = inventoryProvider.showStoreFilter;

    return IcueCenteredBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _typed,
                    onSubmitted: _submitted,
                    decoration: InputDecoration(
                      hintText: 'Search by asset name…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _submitted('');
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openScanDialog,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan asset ID or RFID tag',
                ),
              ],
            ),
          ),
          if (_registeredTab)
            _chipRow([
              for (final MapEntry(:key, :value) in {
                'all': 'All',
                ..._statuses,
              }.entries)
                (
                  label: value,
                  selected: (activeState.status ?? 'all') == key,
                  onSelected: () =>
                      activeState.setStatus(key == 'all' ? null : key),
                ),
            ]),
          if (showStores)
            _chipRow([
              for (final (id, name) in [
                (null, 'All stores'),
                for (final store in inventoryProvider.stores)
                  (store.id, store.name),
              ])
                (
                  label: name,
                  selected: assetsProvider.storeId == id,
                  onSelected: () => assetsProvider.setStore(id),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                Text(
                  pager.loading && pager.items.isEmpty
                      ? 'Loading assets…'
                      : _countSummary(rows.length, pager.hasNext),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isFiltered) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Text(
                      'Clear filters',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pager.error != null && pager.items.isEmpty
                ? IcueEmptyState.error(
                    title: 'Could not load assets',
                    message: '${pager.error}',
                    onAction: pager.retry,
                  )
                : pager.loading && pager.items.isEmpty
                ? const IcueSkeletonCardList()
                : rows.isEmpty
                ? (isFiltered
                      ? IcueEmptyState.noResults(
                          title: 'No matching assets',
                          actionLabel: 'Clear filters',
                          onAction: _clearAllFilters,
                        )
                      : IcueEmptyState(
                          icon: _registeredTab
                              ? Icons.inventory_2_outlined
                              : Icons.task_alt_rounded,
                          title: _registeredTab
                              ? 'No registered assets'
                              : 'All caught up',
                          message: _registeredTab
                              ? 'Receive stock of an asset item, then register each unit from the Unregistered tab.'
                              : 'Every received asset is registered.',
                        ))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: IcueAdaptiveCardList(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      spacing: 8,
                      itemCount: rows.length,
                      footer: IcueLoadMoreFooter.of(pager),
                      itemBuilder: (context, index) {
                        final asset = rows[index];
                        final itemName =
                            assetsProvider.items[asset.itemId]?.name;
                        final storeName = _storeName(
                          inventoryProvider,
                          asset.storeId,
                        );
                        return _registeredTab
                            ? RegisteredAssetCard(
                                asset: asset,
                                itemName: itemName,
                                storeName: showStores ? storeName : null,
                                onTap: () => _open(asset),
                              )
                            : UnregisteredAssetCard(
                                asset: asset,
                                itemName: itemName,
                                storeName: storeName,
                                onRegister: () => _open(asset),
                              );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(
    List<({String label, bool selected, VoidCallback onSelected})> chips,
  ) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final chip in chips)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(chip.label),
              selected: chip.selected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => chip.onSelected(),
            ),
          ),
      ],
    ),
  );

  String _countSummary(int count, bool hasNext) {
    final suffix = hasNext ? '+' : '';
    if (_registeredTab) {
      return '$count$suffix asset${count == 1 && !hasNext ? '' : 's'}';
    }
    return '$count$suffix awaiting registration';
  }
}
