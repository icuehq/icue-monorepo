import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_action_dialog.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_label.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:provider/provider.dart';

/// One asset on its own page: details, the actions allowed in its current status, custody history and timeline (FRS 10.19).
class AssetDetailsPage extends StatefulWidget {
  const AssetDetailsPage({required this.assetId, super.key});

  final String assetId;

  @override
  State<AssetDetailsPage> createState() => _AssetDetailsPageState();
}

class _AssetDetailsPageState extends State<AssetDetailsPage> {
  InventoryAsset? _asset;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final assetsProvider = context.read<AssetsProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    final asset = await assetsProvider.asset(widget.assetId);
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _loaded = true;
    });
    if (asset == null) return;
    await assetsProvider.loadItemNames([asset.itemId]);
    if (mounted) await assetsProvider.loadDetail(asset.id);
  }

  /// Opens an action form, then reloads so the page shows the new status.
  Future<void> _act(Widget Function() form) async {
    await showDialog<void>(context: context, builder: (_) => form());
    if (mounted) await _load();
  }

  List<(String, Widget Function())> _actions(InventoryAsset asset) {
    final manage = context.read<InventoryProvider>().access.can(
      'inventory.assets.manage',
    );
    if (!manage) return const [];
    return [
      if (!asset.isRetired &&
          !asset.inMaintenance &&
          asset.status == 'assigned') ...[
        (
          'Transfer',
          () => AssetActionDialog(asset: asset, action: AssetAction.transfer),
        ),
        (
          'Return',
          () => AssetActionDialog(asset: asset, action: AssetAction.giveBack),
        ),
      ],
      if (!asset.isRetired)
        (
          'Condition',
          () => AssetActionDialog(asset: asset, action: AssetAction.condition),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final assetsProvider = context.watch<AssetsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(asset?.name ?? 'Asset')),
      body: asset == null
          ? Center(
              child: _loaded
                  ? Text(assetsProvider.errorMessage ?? 'Asset not found')
                  : const CircularProgressIndicator(),
            )
          : IcueCenteredBody(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.all(context.isWide ? 24 : 16),
                  children: [
                    _Header(
                      asset: asset,
                      actions: _actions(asset),
                      onAct: _act,
                    ),
                    _DetailsCard(asset: asset),
                    _CustodyCard(assetsProvider: assetsProvider),
                    _HistoryCard(assetsProvider: assetsProvider),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.asset,
    required this.actions,
    required this.onAct,
  });

  final InventoryAsset asset;
  final List<(String, Widget Function())> actions;
  final Future<void> Function(Widget Function() form) onAct;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: asset.name,
    icon: Icons.devices_other_outlined,
    trailing: StatusChip(asset.status),
    children: [
      SelectableText(
        asset.id,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, form) in actions)
            IcueButton(
              label: label,
              onPressed: () => onAct(form),
              variant: IcueButtonVariant.outline,
            ),
          IcueButton(
            label: 'Label',
            onPressed: () => shareAssetLabel(asset),
            variant: IcueButtonVariant.outline,
            leadingIcon: Icons.print_outlined,
          ),
        ],
      ),
    ],
  );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.asset});

  final InventoryAsset asset;

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    final stores = context.watch<InventoryProvider>().stores;
    final store = stores
        .where((store) => store.id == asset.storeId)
        .firstOrNull;
    final fields = <(String, String?)>[
      ('Item', assetsProvider.items[asset.itemId]?.name),
      ('Store', store?.name),
      ('Condition', humanizeStatus(asset.condition)),
      ('Held by', asset.assignedTo?.label),
      ('Location', asset.location),
      ('Serial number', asset.serialNumber),
      ('RFID tag', asset.rfidTag),
      ('Make / model', [asset.make, asset.model].whereType<String>().join(' ')),
      ('Purchased', asset.purchaseDate?.toDisplayDay()),
      ('Price', asset.price?.toRupees()),
      (
        'Warranty',
        asset.warrantyEnd == null
            ? null
            : '${asset.warrantyStart?.toDisplayDay() ?? ''} → '
                  '${asset.warrantyEnd!.toDisplayDay()}',
      ),
      ('Next service', asset.nextServiceDate?.toDisplayDay()),
    ];
    return IcueFormSectionCard(
      title: 'Details',
      icon: Icons.info_outline_rounded,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 520
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                for (final (label, value) in fields)
                  if (value != null && value.trim().isNotEmpty)
                    SizedBox(
                      width: width,
                      child: _Field(label: label, value: value),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _CustodyCard extends StatelessWidget {
  const _CustodyCard({required this.assetsProvider});

  final AssetsProvider assetsProvider;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Custody',
    icon: Icons.person_outline_rounded,
    children: [
      if (assetsProvider.isLoading && assetsProvider.assignments.isEmpty)
        const Center(child: CircularProgressIndicator())
      else if (assetsProvider.assignments.isEmpty)
        const Text('Never assigned')
      else
        for (final assignment in assetsProvider.assignments)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(assignment.assignee.label),
            subtitle: Text(
              '${assignment.assignedDate.toDisplayDay()} → ${assignment.returnedDate?.toDisplayDay() ?? 'now'}'
              '${assignment.closedAs == null ? '' : ' · ${assignment.closedAs}'}'
              '${assignment.conditionOut == null ? '' : ' · out ${assignment.conditionOut}'}'
              '${assignment.conditionIn == null ? '' : ' · in ${assignment.conditionIn}'}'
              '${assignment.acknowledged ? ' · acknowledged' : ''}',
            ),
          ),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.assetsProvider});

  final AssetsProvider assetsProvider;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'History',
    icon: Icons.history_rounded,
    children: [
      if (assetsProvider.isLoading && assetsProvider.history.isEmpty)
        const Center(child: CircularProgressIndicator())
      else if (assetsProvider.history.isEmpty)
        const Text('No history yet')
      else
        for (final assetEvent in assetsProvider.history)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(humanizeStatus(assetEvent.type.replaceAll('.', ' '))),
            subtitle: Text(
              [
                    assetEvent.performedAt?.toLocal().toNumericDateTime(),
                    assetEvent.detail,
                  ]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
            ),
          ),
    ],
  );
}
