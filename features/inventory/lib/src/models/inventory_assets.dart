import 'package:inventory/src/models/inventory_assets.g.dart';

export 'inventory_assets.g.dart';

// Assets, custody and maintenance (Inv-6). Parse and display only; rules live in Cloud Functions.

/// Who holds an asset: `staff`, `student` or `department`, by ERP ID.
class AssetCustodian {
  const AssetCustodian(this.type, this.personErpId);

  static AssetCustodian? from(Object? value) => value is Map
      ? AssetCustodian(
          value['type'] as String? ?? 'staff',
          (value['personErpId'] as num).toInt(),
        )
      : null;

  final String type;
  final int personErpId;

  String get label => '$type #$personErpId';
}

extension InventoryAssetMembers on InventoryAsset {
  bool get isRetired => status == 'retired' || status == 'disposed';
  bool get inMaintenance => activeMaintenanceId != null;
}

class PartUsed {
  const PartUsed({required this.itemId, required this.quantity});

  final String itemId;
  final double quantity;
}

extension InventoryMaintenanceMembers on InventoryMaintenance {
  bool get isLive => status != 'completed' && status != 'cancelled';
}
