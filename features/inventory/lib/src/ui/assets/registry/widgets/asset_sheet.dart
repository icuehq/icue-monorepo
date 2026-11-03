import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/maintenance/widgets/maintenance_form_sheet.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_action_sheet.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_label.dart';
import 'package:inventory/src/ui/assets/registry/widgets/rfid_sheet.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:provider/provider.dart';

/// One asset: details, custody history, timeline and the actions allowed in its current status (FRS 10.19).
class AssetSheet extends StatefulWidget {
  const AssetSheet({required this.asset, super.key});

  final InventoryAsset asset;

  @override
  State<AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends State<AssetSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssetsProvider>().loadDetail(
        context.read<InventoryProvider>().access,
        widget.asset.id,
      );
    });
  }

  /// Opens [then] over this sheet, then closes this one so the list reloads with fresh data.
  Future<void> _open(Widget Function() then) async {
    final navigator = Navigator.of(context);
    await showFormSheet(context, then);
    if (mounted) navigator.pop();
  }

  Widget _row(String currentValue, String? value) =>
      value == null || value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$currentValue: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final assetsProvider = context.watch<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inventory.assets.manage',
    );
    final actions = <(String, Widget Function())>[
      if (manage && !asset.isRetired && !asset.inMaintenance) ...[
        if (asset.status == 'available')
          (
            'Assign',
            () => AssetActionSheet(asset: asset, action: AssetAction.assign),
          ),
        if (asset.status == 'assigned') ...[
          (
            'Transfer',
            () => AssetActionSheet(asset: asset, action: AssetAction.transfer),
          ),
          (
            'Return',
            () => AssetActionSheet(asset: asset, action: AssetAction.giveBack),
          ),
        ],
      ],
      if (manage && !asset.isRetired)
        (
          'Condition',
          () => AssetActionSheet(asset: asset, action: AssetAction.condition),
        ),
      if (manage &&
          !asset.isRetired &&
          !asset.inMaintenance &&
          asset.status != 'assigned')
        (
          'Retire',
          () => AssetActionSheet(asset: asset, action: AssetAction.retire),
        ),
      if (manage && asset.status == 'retired')
        (
          'Dispose',
          () => AssetActionSheet(asset: asset, action: AssetAction.retire),
        ),
      if (manage && !asset.isRetired)
        ('RFID tag', () => RfidSheet(asset: asset)),
      if (manage &&
          !asset.isRetired &&
          asset.status != 'lost' &&
          !asset.inMaintenance)
        ('Report fault', () => MaintenanceFormSheet(asset: asset)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(asset.name, style: Theme.of(context).textTheme.titleLarge),
        Row(
          children: [
            Expanded(child: SelectableText(asset.assetId)),
            StatusChip(asset.status),
          ],
        ),
        const SizedBox(height: 8),
        _row('Condition', humanizeStatus(asset.condition)),
        _row('Serial', asset.serialNumber),
        _row('RFID tag', asset.rfidTag),
        _row(
          'Make / model',
          [asset.make, asset.model].whereType<String>().join(' '),
        ),
        _row('Location', asset.location),
        _row('Held by', asset.assignedTo?.label),
        _row('Purchased', asset.purchaseDate),
        _row('Price', asset.price?.toStringAsFixed(2)),
        _row(
          'Warranty',
          asset.warrantyEnd == null
              ? null
              : '${asset.warrantyStart ?? ''} → ${asset.warrantyEnd}',
        ),
        _row('Next service', asset.nextServiceDate),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (label, form) in actions)
              OutlinedButton(onPressed: () => _open(form), child: Text(label)),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Label'),
              onPressed: () => shareAssetLabel(asset),
            ),
          ],
        ),
        if (assetsProvider.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (assetsProvider.assignments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Custody', style: Theme.of(context).textTheme.titleMedium),
            for (final assignment in assetsProvider.assignments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(assignment.assignee.label),
                subtitle: Text(
                  '${assignment.assignedDate} → ${assignment.returnedDate ?? 'now'}'
                  '${assignment.closedAs == null ? '' : ' · ${assignment.closedAs}'}'
                  '${assignment.conditionOut == null ? '' : ' · out ${assignment.conditionOut}'}'
                  '${assignment.conditionIn == null ? '' : ' · in ${assignment.conditionIn}'}'
                  '${assignment.acknowledged ? ' · acknowledged' : ''}',
                ),
              ),
          ],
          if (assetsProvider.history.isNotEmpty) ...[
            const Divider(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            for (final assetEvent in assetsProvider.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  humanizeStatus(assetEvent.type.replaceAll('.', ' ')),
                ),
                subtitle: Text(
                  [
                        assetEvent.performedAt?.toLocal().toString().substring(
                          0,
                          16,
                        ),
                        assetEvent.detail,
                      ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
