import 'package:icue_firebase/icue_firebase.dart' show readList;

/// Tracking method of an item (FRS 10.3).
enum Tracking {
  quantity('Quantity'),
  batch('Batch'),
  asset('Individual asset');

  const Tracking(this.label);

  final String label;

  static Tracking parse(Object? value) => values.firstWhere(
    (tracking) => tracking.name == value,
    orElse: () => quantity,
  );
}

class InventoryCategory {
  const InventoryCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.suggestedTracking,
    required this.active,
    this.description,
    this.parentId,
  });

  factory InventoryCategory.fromMap(String id, Map<String, dynamic> data) =>
      InventoryCategory(
        id: id,
        code: data['code'] as String? ?? '',
        name: data['name'] as String? ?? '',
        description: data['description'] as String?,
        parentId: data['parentId'] as String?,
        suggestedTracking: Tracking.parse(data['suggestedTracking']),
        active: data['status'] != 'inactive',
      );

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? parentId;
  final Tracking suggestedTracking;
  final bool active;
}

class InventoryUnit {
  const InventoryUnit({required this.code, required this.name});

  factory InventoryUnit.fromMap(String id, Map<String, dynamic> data) =>
      InventoryUnit(code: id, name: data['name'] as String? ?? id);

  final String code;
  final String name;
}

class PurchaseUnit {
  const PurchaseUnit({required this.unit, required this.factor});

  final String unit;
  final double factor;

  Map<String, Object?> toMap() => {'unit': unit, 'factor': factor};
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    required this.stockUnit,
    required this.tracking,
    required this.active,
    this.subcategoryId,
    this.description,
    this.purchaseUnits = const [],
    this.variantAttrs = const [],
    this.minLevel,
    this.reorderLevel,
    this.defaultPrice,
    this.preferredVendorId,
    this.defaultLocation,
  });

  factory InventoryItem.fromMap(String id, Map<String, dynamic> currentData) =>
      InventoryItem(
        id: id,
        code: currentData['code'] as String? ?? '',
        name: currentData['name'] as String? ?? '',
        categoryId: currentData['categoryId'] as String? ?? '',
        subcategoryId: currentData['subcategoryId'] as String?,
        description: currentData['description'] as String?,
        stockUnit: currentData['stockUnit'] as String? ?? '',
        purchaseUnits: [
          for (final data in readList<Map<String, dynamic>>(
            currentData['purchaseUnits'],
          ))
            PurchaseUnit(
              unit: data['unit'] as String? ?? '',
              factor: (data['factor'] as num? ?? 1).toDouble(),
            ),
        ],
        tracking: Tracking.parse(currentData['tracking']),
        variantAttrs: readList<String>(currentData['variantAttrs']),
        minLevel: (currentData['minLevel'] as num?)?.toDouble(),
        reorderLevel: (currentData['reorderLevel'] as num?)?.toDouble(),
        defaultPrice: (currentData['defaultPrice'] as num?)?.toDouble(),
        preferredVendorId: currentData['preferredVendorId'] as String?,
        defaultLocation: currentData['defaultLocation'] as String?,
        active: currentData['status'] != 'inactive',
      );

  final String id;
  final String code;
  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String? description;
  final String stockUnit;
  final List<PurchaseUnit> purchaseUnits;
  final Tracking tracking;
  final List<String> variantAttrs;
  final double? minLevel;
  final double? reorderLevel;
  final double? defaultPrice;
  final String? preferredVendorId;
  final String? defaultLocation;
  final bool active;
}

class InventoryVariant {
  const InventoryVariant({
    required this.id,
    required this.sku,
    required this.attrs,
    required this.active,
  });

  factory InventoryVariant.fromMap(String id, Map<String, dynamic> data) =>
      InventoryVariant(
        id: id,
        sku: data['sku'] as String? ?? '',
        attrs: (data['attrs'] as Map<String, dynamic>? ?? {}).map(
          (currentValue, value) => MapEntry(currentValue, '$value'),
        ),
        active: data['status'] != 'inactive',
      );

  final String id;
  final String sku;
  final Map<String, String> attrs;
  final bool active;
}

class InventoryStore {
  const InventoryStore({
    required this.id,
    required this.code,
    required this.name,
    required this.campusId,
    required this.storekeeperIds,
    required this.active,
    this.description,
    this.location,
  });

  factory InventoryStore.fromMap(String id, Map<String, dynamic> data) =>
      InventoryStore(
        id: id,
        code: data['code'] as String? ?? '',
        name: data['name'] as String? ?? '',
        campusId: (data['campusId'] as num? ?? 0).toInt(),
        description: data['description'] as String?,
        location: data['location'] as String?,
        storekeeperIds: [
          for (final number in readList<num>(data['storekeeperIds']))
            number.toInt(),
        ],
        active: data['status'] != 'inactive',
      );

  final String id;
  final String code;
  final String name;
  final int campusId;
  final String? description;
  final String? location;
  final List<int> storekeeperIds;
  final bool active;
}
