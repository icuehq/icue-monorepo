import 'package:hive/hive.dart';

/// Centralized storage service interface for persisting and retrieving application data.
abstract class StorageService {
  /// Initializes the local storage engine (e.g. Hive.initFlutter) and registers adapters.
  Future<void> init();

  /// Opens a box with the given name if not already open.
  Future<Box<T>> openBox<T>(String boxName);

  /// Returns an already opened box. Throws an error or opens it if not yet open.
  Box<T> getBox<T>(String boxName);

  /// Checks if a box is currently open.
  bool isBoxOpen(String boxName);

  /// Stores a value under [key] in [boxName].
  Future<void> put<T>(String boxName, dynamic key, T value);

  /// Retrieves a value under [key] from [boxName], returning [defaultValue] if null.
  T? get<T>(String boxName, dynamic key, {T? defaultValue});

  /// Deletes a key-value entry from [boxName].
  Future<void> delete(String boxName, dynamic key);

  /// Checks if [boxName] contains [key].
  bool containsKey(String boxName, dynamic key);

  /// Retrieves all values stored in [boxName].
  List<T> getAll<T>(String boxName);

  /// Clears all entries in [boxName].
  Future<void> clearBox(String boxName);

  /// Clears all known and open storage boxes (e.g. on user logout).
  Future<void> clearAll();

  /// Closes all open boxes safely.
  Future<void> closeAll();
}
