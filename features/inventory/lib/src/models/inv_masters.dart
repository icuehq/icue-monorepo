/// Tracking method of an item (FRS 10.3).
enum Tracking {
  qty('Quantity'),
  batch('Batch'),
  asset('Individual asset');

  const Tracking(this.label);

  final String label;

  static Tracking parse(Object? v) =>
      values.firstWhere((t) => t.name == v, orElse: () => qty);
}

List<T> _list<T>(Object? v) => v is List ? List<T>.from(v) : <T>[];

class InvCategory {
  const InvCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.suggestedTracking,
    required this.active,
    this.description,
    this.parentId,
  });

  factory InvCategory.fromMap(String id, Map<String, dynamic> m) => InvCategory(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    description: m['description'] as String?,
    parentId: m['parentId'] as String?,
    suggestedTracking: Tracking.parse(m['suggestedTracking']),
    active: m['status'] != 'inactive',
  );

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? parentId;
  final Tracking suggestedTracking;
  final bool active;
}

class InvUnit {
  const InvUnit({required this.code, required this.name});

  factory InvUnit.fromMap(String id, Map<String, dynamic> m) =>
      InvUnit(code: id, name: m['name'] as String? ?? id);

  final String code;
  final String name;
}

class PurchaseUnit {
  const PurchaseUnit({required this.unit, required this.factor});

  final String unit;
  final double factor;

  Map<String, Object?> toMap() => {'unit': unit, 'factor': factor};
}

class InvItem {
  const InvItem({
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

  factory InvItem.fromMap(String id, Map<String, dynamic> m) => InvItem(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    categoryId: m['categoryId'] as String? ?? '',
    subcategoryId: m['subcategoryId'] as String?,
    description: m['description'] as String?,
    stockUnit: m['stockUnit'] as String? ?? '',
    purchaseUnits: [
      for (final p in _list<Map<String, dynamic>>(m['purchaseUnits']))
        PurchaseUnit(
          unit: p['unit'] as String? ?? '',
          factor: (p['factor'] as num? ?? 1).toDouble(),
        ),
    ],
    tracking: Tracking.parse(m['tracking']),
    variantAttrs: _list<String>(m['variantAttrs']),
    minLevel: (m['minLevel'] as num?)?.toDouble(),
    reorderLevel: (m['reorderLevel'] as num?)?.toDouble(),
    defaultPrice: (m['defaultPrice'] as num?)?.toDouble(),
    preferredVendorId: m['preferredVendorId'] as String?,
    defaultLocation: m['defaultLocation'] as String?,
    active: m['status'] != 'inactive',
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

class InvVariant {
  const InvVariant({
    required this.id,
    required this.sku,
    required this.attrs,
    required this.active,
  });

  factory InvVariant.fromMap(String id, Map<String, dynamic> m) => InvVariant(
    id: id,
    sku: m['sku'] as String? ?? '',
    attrs: (m['attrs'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, '$v'),
    ),
    active: m['status'] != 'inactive',
  );

  final String id;
  final String sku;
  final Map<String, String> attrs;
  final bool active;
}

class InvStore {
  const InvStore({
    required this.id,
    required this.code,
    required this.name,
    required this.campusId,
    required this.storekeeperIds,
    required this.active,
    this.description,
    this.location,
  });

  factory InvStore.fromMap(String id, Map<String, dynamic> m) => InvStore(
    id: id,
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    description: m['description'] as String?,
    location: m['location'] as String?,
    storekeeperIds: [
      for (final n in _list<num>(m['storekeeperIds'])) n.toInt(),
    ],
    active: m['status'] != 'inactive',
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

/// The signed-in user's resolved permissions (`userAccess/{uid}`).
class InvAccess {
  const InvAccess({
    this.perms = const {},
    this.campuses = const [],
    this.all = false,
  });

  factory InvAccess.fromMap(Map<String, dynamic> m) => InvAccess(
    perms: _list<String>(m['perms']).toSet(),
    campuses: [for (final n in _list<num>(m['cmp'])) n.toInt()],
    all: m['all'] == true,
  );

  final Set<String> perms;
  final List<int> campuses;
  final bool all;

  bool can(String perm) => perms.contains(perm);
}
