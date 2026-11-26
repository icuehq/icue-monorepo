import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';

/// Formats an [AssetCustodian] for display (e.g. `Staff #104`).
String formatCustodian(AssetCustodian custodian) =>
    '${humanizeStatus(custodian.type)} #${custodian.personErpId}';

/// Combines make/model and catalog item name (when different from the asset name).
String assetSubtitle(InventoryAsset asset, String? itemName) {
  final makeModel = [
    asset.make,
    asset.model,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  final showItem =
      itemName != null &&
      itemName.isNotEmpty &&
      itemName != asset.itemId &&
      itemName.toLowerCase() != asset.name.toLowerCase();
  return [
    if (makeModel.isNotEmpty) makeModel,
    if (showItem) itemName,
  ].join(' · ');
}

/// Mobile card for a registered asset.
class RegisteredAssetCard extends StatelessWidget {
  const RegisteredAssetCard({
    required this.asset,
    required this.onTap,
    this.itemName,
    this.storeName,
    super.key,
  });

  final InventoryAsset asset;
  final String? itemName;
  final String? storeName;
  final VoidCallback onTap;

  IconData get _icon => asset.inMaintenance
      ? Icons.build_outlined
      : asset.isRetired
      ? Icons.archive_outlined
      : Icons.devices_other_outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = inventoryStatusColor(asset.status);
    final subtitle = assetSubtitle(asset, itemName);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                asset.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InventoryStatusChip(asset.status),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaPill(icon: Icons.qr_code_2_rounded, text: asset.id),
                  if (asset.serialNumber != null &&
                      asset.serialNumber!.isNotEmpty)
                    _MetaPill(
                      icon: Icons.tag_rounded,
                      text: 'S/N ${asset.serialNumber!}',
                    ),
                  if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                    _MetaPill(
                      icon: Icons.nfc_rounded,
                      text: 'RFID ${asset.rfidTag!}',
                    ),
                  _MetaPill(
                    icon: Icons.verified_outlined,
                    text: humanizeStatus(asset.condition),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (storeName != null && storeName!.isNotEmpty) ...[
                    Icon(
                      Icons.storefront_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        storeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    asset.assignedTo == null
                        ? Icons.warehouse_outlined
                        : Icons.person_outline_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      asset.assignedTo == null
                          ? 'In store'
                          : formatCustodian(asset.assignedTo!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: asset.assignedTo == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        fontWeight: asset.assignedTo == null
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile card for a received asset unit awaiting registration.
class UnregisteredAssetCard extends StatelessWidget {
  const UnregisteredAssetCard({
    required this.asset,
    required this.storeName,
    required this.onRegister,
    this.itemName,
    super.key,
  });

  final InventoryAsset asset;
  final String storeName;
  final String? itemName;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = assetSubtitle(asset, itemName);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.35)),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRegister,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pending_actions_rounded,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                asset.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const InventoryStatusChip('unregistered'),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle.isEmpty
                              ? asset.id
                              : '$subtitle · ${asset.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _InlineMeta(
                          icon: Icons.storefront_outlined,
                          text: storeName,
                        ),
                        if (asset.receivedDate != null)
                          _InlineMeta(
                            icon: Icons.event_outlined,
                            text: asset.receivedDate!.toDisplayDay(),
                          ),
                        if (asset.price != null)
                          _InlineMeta(
                            icon: Icons.payments_outlined,
                            text: asset.price!.toRupees(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: onRegister,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
