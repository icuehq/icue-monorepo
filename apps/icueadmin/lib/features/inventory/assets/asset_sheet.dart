import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/assets/asset_action_sheet.dart';
import 'package:icueadmin/features/inventory/assets/asset_label.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/assets/maintenance_form_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One asset: details, custody history, timeline and the actions allowed in its current status (FRS 10.19).
class AssetSheet extends StatefulWidget {
  const AssetSheet({required this.asset, super.key});

  final InvAsset asset;

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
    final nav = Navigator.of(context);
    await showInvSheet(context, then);
    if (mounted) nav.pop();
  }

  Widget _row(String k, String? v) => v == null || v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$k: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: v),
              ],
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final p = context.watch<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inv.assets.manage',
    );
    final actions = <(String, Widget Function())>[
      if (manage && !a.isRetired && !a.inMaintenance) ...[
        if (a.status == 'available')
          (
            'Assign',
            () => AssetActionSheet(asset: a, action: AssetAction.assign),
          ),
        if (a.status == 'assigned') ...[
          (
            'Transfer',
            () => AssetActionSheet(asset: a, action: AssetAction.transfer),
          ),
          (
            'Return',
            () => AssetActionSheet(asset: a, action: AssetAction.giveBack),
          ),
        ],
      ],
      if (manage && !a.isRetired)
        (
          'Condition',
          () => AssetActionSheet(asset: a, action: AssetAction.condition),
        ),
      if (manage && !a.isRetired && !a.inMaintenance && a.status != 'assigned')
        (
          'Retire',
          () => AssetActionSheet(asset: a, action: AssetAction.retire),
        ),
      if (manage && a.status == 'retired')
        (
          'Dispose',
          () => AssetActionSheet(asset: a, action: AssetAction.retire),
        ),
      if (manage && !a.isRetired && a.status != 'lost' && !a.inMaintenance)
        ('Report fault', () => MaintenanceFormSheet(asset: a)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(a.name, style: Theme.of(context).textTheme.titleLarge),
        Row(
          children: [
            Expanded(child: SelectableText(a.assetId)),
            StatusChip(a.status),
          ],
        ),
        const SizedBox(height: 8),
        _row('Condition', statusLabel(a.condition)),
        _row('Serial', a.serialNo),
        _row('Make / model', [a.make, a.model].whereType<String>().join(' ')),
        _row('Location', a.location),
        _row('Held by', a.assignedTo?.label),
        _row('Purchased', a.purchaseDate),
        _row('Price', a.price?.toStringAsFixed(2)),
        _row(
          'Warranty',
          a.warrantyEnd == null
              ? null
              : '${a.warrantyStart ?? ''} → ${a.warrantyEnd}',
        ),
        _row('Next service', a.nextServiceDate),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (label, form) in actions)
              OutlinedButton(onPressed: () => _open(form), child: Text(label)),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Label'),
              onPressed: () => shareAssetLabel(a),
            ),
          ],
        ),
        if (p.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (p.assignments.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Custody', style: Theme.of(context).textTheme.titleMedium),
            for (final g in p.assignments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(g.assignee.label),
                subtitle: Text(
                  '${g.assignedDate} → ${g.returnedDate ?? 'now'}'
                  '${g.closedAs == null ? '' : ' · ${g.closedAs}'}'
                  '${g.conditionOut == null ? '' : ' · out ${g.conditionOut}'}'
                  '${g.conditionIn == null ? '' : ' · in ${g.conditionIn}'}'
                  '${g.acknowledged ? ' · acknowledged' : ''}',
                ),
              ),
          ],
          if (p.history.isNotEmpty) ...[
            const Divider(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            for (final e in p.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(statusLabel(e.type.replaceAll('.', ' '))),
                subtitle: Text(
                  [
                    e.at?.toLocal().toString().substring(0, 16),
                    e.detail,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
