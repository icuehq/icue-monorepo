import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late Directory tempDir;
  late StorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    storageService = StorageService();
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
}
