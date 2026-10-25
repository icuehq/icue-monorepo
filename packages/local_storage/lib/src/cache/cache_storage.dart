import 'package:injectable/injectable.dart';
import 'package:local_storage/src/constants/storage_constants.dart';
import 'package:local_storage/src/service/storage_service.dart';

/// Centralized response and feature data cache with optional Time-To-Live (TTL).
@lazySingleton
class CacheStorage {
  CacheStorage(this._storageService);

  final StorageService _storageService;

  /// Caches [value] under [key] in [StorageConstants.appCacheBox].
  /// If [ttl] is provided, the entry expires automatically after that duration.
  Future<void> put<T>(String key, T value, {Duration? ttl}) async {
    final entry = <String, dynamic>{
      'data': value,
      if (ttl != null)
        'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
    };

    await _storageService.put<dynamic>(
      StorageConstants.appCacheBox,
      key,
      entry,
    );
  }

  /// Retrieves cached value for [key].
  /// Returns `null` if not found or if the entry has expired.
  T? get<T>(String key) {
    final raw = _storageService.get<dynamic>(
      StorageConstants.appCacheBox,
      key,
    );

    if (raw == null) return null;

    if (raw is Map) {
      final expiresAt = raw['expiresAt'] as int?;
      if (expiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > expiresAt) {
        // Expired entry - evict lazily
        delete(key);
        return null;
      }
      return raw['data'] as T?;
    }

    return raw as T?;
  }

  /// Removes [key] from cache.
  Future<void> delete(String key) async {
    await _storageService.delete(StorageConstants.appCacheBox, key);
  }

  /// Checks if [key] is in cache and unexpired.
  bool contains(String key) {
    return get<dynamic>(key) != null;
  }

  /// Clears the entire cache box.
  Future<void> clear() async {
    await _storageService.clearBox(StorageConstants.appCacheBox);
  }
}
