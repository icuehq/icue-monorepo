import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late Directory tempDir;
  late HiveStorageService storageService;
  late CacheStorage cacheStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    storageService = HiveStorageService();
    cacheStorage = CacheStorage(storageService);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageService operations', () {
    test('put and get generic values', () async {
      await storageService.put<String>('test_box', 'greeting', 'hello');

      final value = storageService.get<String>('test_box', 'greeting');
      expect(value, equals('hello'));
      expect(storageService.containsKey('test_box', 'greeting'), isTrue);
    });

    test('delete and containsKey', () async {
      await storageService.put<int>('test_box', 'count', 42);
      expect(storageService.get<int>('test_box', 'count'), equals(42));

      await storageService.delete('test_box', 'count');
      expect(storageService.get<int>('test_box', 'count'), isNull);
      expect(storageService.containsKey('test_box', 'count'), isFalse);
    });

    test('getAll returns all values', () async {
      await storageService.put<String>('fruits', 'a', 'Apple');
      await storageService.put<String>('fruits', 'b', 'Banana');

      final all = storageService.getAll<String>('fruits');
      expect(all, containsAll(['Apple', 'Banana']));
    });

    test('clearBox removes all entries in the box', () async {
      await storageService.put<String>('fruits', 'a', 'Apple');
      await storageService.clearBox('fruits');

      expect(storageService.getAll<String>('fruits'), isEmpty);
    });
  });

  group('CacheStorage operations', () {
    test('put and get unexpired cache entry', () async {
      await cacheStorage.put('profile_data', {'name': 'Alice'});

      final data = cacheStorage.get<Map<dynamic, dynamic>>('profile_data');
      expect(data, isNotNull);
      expect(data!['name'], equals('Alice'));
    });

    test('cache entry with expired TTL returns null and is evicted', () async {
      await cacheStorage.put(
        'short_lived',
        'transient_value',
        ttl: const Duration(milliseconds: -100),
      );

      final data = cacheStorage.get<String>('short_lived');
      expect(data, isNull);
      expect(cacheStorage.contains('short_lived'), isFalse);
    });

    test('delete and clear cache', () async {
      await cacheStorage.put('k1', 'v1');
      await cacheStorage.put('k2', 'v2');

      await cacheStorage.delete('k1');
      expect(cacheStorage.get<String>('k1'), isNull);
      expect(cacheStorage.get<String>('k2'), equals('v2'));

      await cacheStorage.clear();
      expect(cacheStorage.get<String>('k2'), isNull);
    });
  });
}
