import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/src/constants/storage_constants.dart';
import 'package:local_storage/src/service/storage_service.dart';

@lazySingleton
class HiveStorageService implements StorageService {
  bool _isInitialized = false;
  final Map<String, dynamic> _openBoxes = {};

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Eagerly open core shared system boxes
    await Future.wait([
      openBox<String>(StorageConstants.fcmTokenBox),
      openBox<dynamic>(StorageConstants.appCacheBox),
    ]);

    _isInitialized = true;
  }

  @override
  Future<Box<T>> openBox<T>(String boxName) async {
    final lower = boxName.toLowerCase();
    if (_openBoxes.containsKey(lower) && Hive.isBoxOpen(boxName)) {
      return _openBoxes[lower] as Box<T>;
    }
    final box = await Hive.openBox<T>(boxName);
    _openBoxes[lower] = box;
    return box;
  }

  @override
  Box<T> getBox<T>(String boxName) {
    final lower = boxName.toLowerCase();
    if (_openBoxes.containsKey(lower)) {
      return _openBoxes[lower] as Box<T>;
    }
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError(
        'Box "$boxName" is not open. Call openBox("$boxName") before accessing it.',
      );
    }
    final box = Hive.box<T>(boxName);
    _openBoxes[lower] = box;
    return box;
  }

  @override
  bool isBoxOpen(String boxName) => Hive.isBoxOpen(boxName);

  dynamic _findBox(String boxName) {
    final lower = boxName.toLowerCase();
    if (_openBoxes.containsKey(lower)) {
      return _openBoxes[lower];
    }
    if (Hive.isBoxOpen(boxName)) {
      try {
        final box = Hive.box<dynamic>(boxName);
        _openBoxes[lower] = box;
        return box;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> put<T>(String boxName, dynamic key, T value) async {
    final box = await openBox<T>(boxName);
    await box.put(key, value);
  }

  @override
  T? get<T>(String boxName, dynamic key, {T? defaultValue}) {
    final lower = boxName.toLowerCase();
    if (_openBoxes.containsKey(lower)) {
      final box = _openBoxes[lower];
      return (box as dynamic).get(key, defaultValue: defaultValue) as T?;
    }
    if (!Hive.isBoxOpen(boxName)) return defaultValue;
    try {
      final box = Hive.box<T>(boxName);
      _openBoxes[lower] = box;
      return box.get(key, defaultValue: defaultValue);
    } catch (_) {
      return defaultValue;
    }
  }

  @override
  Future<void> delete(String boxName, dynamic key) async {
    final box = _findBox(boxName);
    if (box != null) {
      await (box as dynamic).delete(key);
    }
  }

  @override
  bool containsKey(String boxName, dynamic key) {
    final box = _findBox(boxName);
    if (box == null) return false;
    return (box as dynamic).containsKey(key) as bool;
  }

  @override
  List<T> getAll<T>(String boxName) {
    final lower = boxName.toLowerCase();
    if (_openBoxes.containsKey(lower)) {
      final box = _openBoxes[lower];
      return ((box as dynamic).values as Iterable).cast<T>().toList();
    }
    if (!Hive.isBoxOpen(boxName)) return <T>[];
    try {
      final box = Hive.box<T>(boxName);
      _openBoxes[lower] = box;
      return box.values.toList();
    } catch (_) {
      return <T>[];
    }
  }

  @override
  Future<void> clearBox(String boxName) async {
    final box = _findBox(boxName);
    if (box != null) {
      await (box as dynamic).clear();
      return;
    }
    final opened = await openBox<dynamic>(boxName);
    await opened.clear();
  }

  @override
  Future<void> clearAll() async {
    final knownBoxes = [
      StorageConstants.userInfoBox,
      StorageConstants.fcmTokenBox,
      StorageConstants.getActionsByRoleBox,
      StorageConstants.standardsBox,
      StorageConstants.announcementTitleBox,
      StorageConstants.routesBox,
      StorageConstants.vehicleBox,
      StorageConstants.vehicleDetailsBox,
      StorageConstants.createAttendanceBox,
      StorageConstants.personTypesBox,
      StorageConstants.fuelPriceBox,
      StorageConstants.zonalBranchBox,
      StorageConstants.expenseTypesBox,
      StorageConstants.expenseCategoryBox,
      StorageConstants.fuelStorageBox,
      StorageConstants.appCacheBox,
    ];

    for (final boxName in knownBoxes) {
      try {
        await clearBox(boxName);
      } catch (e) {
        debugPrint('Error clearing box $boxName: $e');
      }
    }
  }

  @override
  Future<void> closeAll() async {
    _openBoxes.clear();
    await Hive.close();
    _isInitialized = false;
  }
}
