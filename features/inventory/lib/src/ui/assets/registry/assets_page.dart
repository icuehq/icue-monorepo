import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show AssetStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
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
    ..addListener(() => setState(() {}));
  Timer? _debounce;

  bool get _registeredTab => _tabs.index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    super.dispose();
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

  /// Typing searches by asset name (prefix, as written) after a short pause.
  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final assetsProvider = context.read<AssetsProvider>();
      (_registeredTab
              ? assetsProvider.assetList
              : assetsProvider.unregisteredList)
          .setSearch(value);
    });
  }

  /// A scan opens the asset with that ID or RFID tag, even outside the loaded list.
  Future<void> _scanned(String code) async {
    final assetsProvider = context.read<AssetsProvider>();
    final asset = await assetsProvider.findByCode(code);
    if (!mounted) return;
    if (asset == null) {
      IcueToast.error(
        context,
        assetsProvider.errorMessage ?? 'No asset "$code"',
      );
      return;
    }
    await _open(asset);
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

  String _storeName(String id) =>
      context
          .read<InventoryProvider>()
          .stores
          .where((store) => store.id == id)
          .firstOrNull
          ?.name ??
      id;

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final waiting = assetsProvider.unregisteredList.pager.items.length;
    final storeFilter = inventoryProvider.showStoreFilter
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (id, name) in [
                  (null, 'All stores'),
                  for (final store in inventoryProvider.stores)
                    (store.id, store.name),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: assetsProvider.storeId == id,
                      onSelected: (_) => assetsProvider.setStore(id),
                    ),
                  ),
              ],
            ),
          )
        : null;
    final storeTableFilters = [
      if (inventoryProvider.showStoreFilter)
        IcueTableFilter(
          id: 'store',
          label: 'Store',
          options: [
            for (final store in inventoryProvider.stores)
              IcueTableFilterOption(store.id, store.name),
          ],
          value: assetsProvider.storeId,
          onChanged: assetsProvider.setStore,
        ),
    ];
    final tabBar = TabBar(
      controller: _tabs,
      tabs: [
        const Tab(text: 'Registered'),
        Tab(
          text: waiting == 0
              ? 'Unregistered'
              : 'Unregistered ($waiting${assetsProvider.unregisteredList.pager.hasNext ? '+' : ''})',
        ),
      ],
    );
    final header = IcueScanField(
      hint: 'Search by name, or scan asset ID or tag',
      onChanged: _typed,
      onScan: _scanned,
    );
    return _registeredTab
        ? _registered(
            assetsProvider,
            tabBar,
            header,
            storeFilter,
            storeTableFilters,
          )
        : _unregistered(
            assetsProvider,
            tabBar,
            header,
            storeFilter,
            storeTableFilters,
          );
  }

  Widget _registered(
    AssetsProvider assetsProvider,
    TabBar tabBar,
    Widget header,
    Widget? storeFilter,
    List<IcueTableFilter> storeTableFilters,
  ) {
    const empty =
        'No registered assets yet. Receive stock of an asset item, then '
        'register each unit from the Unregistered tab.';
    return PagedListPage<InventoryAsset>(
      key: const ValueKey('registered'),
      title: 'Asset management',
      appBarBottom: tabBar,
      state: assetsProvider.assetList,
      statuses: _statuses,
      emptyIcon: Icons.inventory_2_outlined,
      emptyMessage: empty,
      onRefresh: _load,
      filterRow: storeFilter,
      header: header,
      itemCard: (context, asset) => ListTile(
        title: Text(asset.name),
        subtitle: Text(
          '${asset.id}${asset.assignedTo == null ? '' : ' · ${asset.assignedTo!.label}'}',
        ),
        trailing: InventoryStatusChip(asset.status),
        onTap: () => _open(asset),
      ),
      table: PagedListTable<InventoryAsset>(
        title: 'Registered assets',
        state: assetsProvider.assetList,
        statuses: _statuses,
        searchHint: 'Asset name (starts with)',
        rowKey: (asset) => asset.id,
        rowLabel: (asset) => asset.name,
        onOpen: _open,
        emptyMessage: empty,
        extraFilters: storeTableFilters,
        extraFiltered: assetsProvider.storeId != null,
        onClearFilters: assetsProvider.clearFilters,
        columns: [
          IcueTableColumn(
            id: 'name',
            label: 'Asset',
            flex: 3,
            minWidth: 200,
            cellBuilder: (context, asset) => IcueTableCellText(
              asset.name,
              subtitle: [
                asset.make,
                asset.model,
              ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
            ),
          ),
          IcueTableColumn(
            id: 'id',
            label: 'ID',
            flex: 2,
            cellBuilder: (context, asset) =>
                IcueTableCellText(asset.id, subtitle: asset.serialNumber),
          ),
          IcueTableColumn(
            id: 'assignedTo',
            label: 'Assigned to',
            flex: 2,
            hideBelowWidth: 900,
            cellBuilder: (context, asset) => IcueTableCellText(
              asset.assignedTo?.label ?? '—',
              style: IcueTableStyle.of(context).secondary,
            ),
          ),
          IcueTableColumn(
            id: 'condition',
            label: 'Condition',
            hideBelowWidth: 1100,
            cellBuilder: (context, asset) => IcueTableCellText(
              humanizeStatus(asset.condition),
              style: IcueTableStyle.of(context).secondary,
            ),
          ),
          IcueTableColumn(
            id: 'status',
            label: 'Status',
            cellBuilder: (context, asset) => IcueStatusPill(
              label: humanizeStatus(asset.status),
              color: inventoryStatusColor(asset.status),
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _unregistered(
    AssetsProvider assetsProvider,
    TabBar tabBar,
    Widget header,
    Widget? storeFilter,
    List<IcueTableFilter> storeTableFilters,
  ) {
    const empty = 'Every received asset is registered.';
    String received(InventoryAsset asset) => asset.receivedDate == null
        ? ''
        : 'Received ${asset.receivedDate!.toDisplayDay()}';
    return PagedListPage<InventoryAsset>(
      key: const ValueKey('unregistered'),
      title: 'Asset management',
      appBarBottom: tabBar,
      state: assetsProvider.unregisteredList,
      statuses: const {},
      emptyIcon: Icons.task_alt_rounded,
      emptyMessage: empty,
      onRefresh: _load,
      filterRow: storeFilter,
      header: header,
      itemCard: (context, asset) => ListTile(
        title: Text(asset.name),
        subtitle: Text(
          [
            _storeName(asset.storeId),
            received(asset),
          ].where((part) => part.isNotEmpty).join(' · '),
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _open(asset),
          child: const Text('Register'),
        ),
        onTap: () => _open(asset),
      ),
      table: PagedListTable<InventoryAsset>(
        title: 'Unregistered assets',
        state: assetsProvider.unregisteredList,
        statuses: const {},
        searchHint: 'Asset name (starts with)',
        rowKey: (asset) => asset.id,
        rowLabel: (asset) => asset.name,
        onOpen: _open,
        emptyMessage: empty,
        extraFilters: storeTableFilters,
        extraFiltered: assetsProvider.storeId != null,
        onClearFilters: assetsProvider.clearFilters,
        columns: [
          IcueTableColumn(
            id: 'name',
            label: 'Asset',
            flex: 3,
            minWidth: 200,
            cellBuilder: (context, asset) =>
                IcueTableCellText(asset.name, subtitle: asset.id),
          ),
          IcueTableColumn(
            id: 'store',
            label: 'Store',
            flex: 2,
            cellBuilder: (context, asset) =>
                IcueTableCellText(_storeName(asset.storeId)),
          ),
          IcueTableColumn(
            id: 'received',
            label: 'Received',
            hideBelowWidth: 900,
            cellBuilder: (context, asset) => IcueTableCellText(
              received(asset).replaceFirst('Received ', ''),
              style: IcueTableStyle.of(context).secondary,
            ),
          ),
          IcueTableColumn(
            id: 'cost',
            label: 'Cost',
            hideBelowWidth: 1100,
            cellBuilder: (context, asset) => IcueTableCellText(
              asset.price?.toRupees() ?? '—',
              style: IcueTableStyle.of(context).secondary,
            ),
          ),
          IcueTableColumn(
            id: 'action',
            label: '',
            cellBuilder: (context, asset) => FilledButton.tonal(
              onPressed: () => _open(asset),
              child: const Text('Register'),
            ),
          ),
        ],
      ),
    );
  }
}
