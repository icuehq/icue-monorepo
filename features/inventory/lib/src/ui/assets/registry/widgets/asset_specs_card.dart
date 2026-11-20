import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_stat_tile.dart';

/// Specifications and identification card (item, store, serial, RFID, make, model).
class AssetSpecsCard extends StatelessWidget {
  const AssetSpecsCard({
    required this.asset,
    required this.itemName,
    required this.storeName,
    super.key,
  });

  final InventoryAsset asset;
  final String? itemName;
  final String? storeName;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Specifications & Identification',
    icon: Icons.qr_code_2_rounded,
    children: [
      DetailInfoRow(
        icon: Icons.inventory_2_outlined,
        label: 'Catalog Item',
        value: itemName ?? '—',
      ),
      DetailInfoRow(
        icon: Icons.storefront_outlined,
        label: 'Store',
        value: storeName ?? '—',
      ),
      DetailInfoRow(
        icon: Icons.domain_outlined,
        label: 'Manufacturer / Make',
        value: asset.make ?? '—',
      ),
      DetailInfoRow(
        icon: Icons.devices_outlined,
        label: 'Model / Variant',
        value: asset.model ?? '—',
      ),
      DetailInfoRow(
        icon: Icons.tag_rounded,
        label: 'Hardware Serial Number',
        value: asset.serialNumber ?? '—',
        copyable: asset.serialNumber != null && asset.serialNumber!.isNotEmpty,
      ),
      if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
        DetailInfoRow(
          icon: Icons.nfc_rounded,
          label: 'RFID Tag',
          value: asset.rfidTag!,
          copyable: true,
        ),
    ],
  );
}

/// Purchase, financial and warranty information.
class AssetFinancialCard extends StatelessWidget {
  const AssetFinancialCard({required this.asset, super.key});

  final InventoryAsset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWarrantyExpired =
        asset.warrantyEnd != null &&
        asset.warrantyEnd!.compareTo(todayIST()) < 0;
    final isWarrantyActive =
        asset.warrantyEnd != null &&
        asset.warrantyEnd!.compareTo(todayIST()) >= 0;

    Widget? warrantyBadge;
    if (isWarrantyExpired) {
      warrantyBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Expired',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (isWarrantyActive) {
      warrantyBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Active',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final warrantyText = asset.warrantyEnd == null
        ? null
        : '${asset.warrantyStart?.toDisplayDay() ?? 'Start'} → ${asset.warrantyEnd!.toDisplayDay()}';

    return IcueFormSectionCard(
      title: 'Purchase & Warranty',
      icon: Icons.receipt_long_outlined,
      children: [
        DetailInfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Purchase Date',
          value: asset.purchaseDate?.toDisplayDay() ?? '—',
        ),
        DetailInfoRow(
          icon: Icons.payments_outlined,
          label: 'Purchase Price',
          value: asset.price?.toRupees() ?? '—',
        ),
        DetailInfoRow(
          icon: Icons.verified_user_outlined,
          label: 'Warranty Period',
          value: warrantyText ?? 'No warranty recorded',
          badge: warrantyBadge,
        ),
        if (asset.nextServiceDate != null)
          DetailInfoRow(
            icon: Icons.build_outlined,
            label: 'Next Scheduled Service',
            value: asset.nextServiceDate!.toDisplayDay(),
          ),
        if (asset.purchaseOrderId != null && asset.purchaseOrderId!.isNotEmpty)
          DetailInfoRow(
            icon: Icons.shopping_bag_outlined,
            label: 'Purchase Order ID',
            value: asset.purchaseOrderId!,
            copyable: true,
          ),
      ],
    );
  }
}
