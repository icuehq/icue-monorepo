import 'dart:convert';

import 'package:auth/src/models/parent_user.dart';
import 'package:injectable/injectable.dart';
import 'package:local_storage/local_storage.dart';

/// Persists the signed-in parent's session (token, mobile, students and the
/// selected student) as plain strings in one Hive box.
@lazySingleton
class ParentSessionStorage {
  ParentSessionStorage(this._storage);

  static const _box = 'parentSession-v1';
  static const _tokenKey = 'token';
  static const _mobileKey = 'mobile';
  static const _parentIdKey = 'parentId';
  static const _studentsKey = 'students';
  static const _selectedKey = 'selected';

  final StorageService _storage;

  /// Opens the box; call once at startup before reading the session.
  Future<void> init() => _storage.openBox<String>(_box);

  String? _read(String key) => _storage.get<String>(_box, key);

  String? get token => _read(_tokenKey);
  String? get mobile => _read(_mobileKey);
  int? get parentId => int.tryParse(_read(_parentIdKey) ?? '');

  List<ParentStudent> get students {
    final raw = _read(_studentsKey);
    if (raw == null) return <ParentStudent>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => ParentStudent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  ParentStudent? get selected {
    final raw = _read(_selectedKey);
    if (raw == null) return null;
    return ParentStudent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession({
    String? token,
    String? mobile,
    int? parentId,
  }) async {
    if (token != null) await _storage.put<String>(_box, _tokenKey, token);
    if (mobile != null) await _storage.put<String>(_box, _mobileKey, mobile);
    if (parentId != null) {
      await _storage.put<String>(_box, _parentIdKey, '$parentId');
    }
  }

  Future<void> saveStudents(List<ParentStudent> students) =>
      _storage.put<String>(
        _box,
        _studentsKey,
        jsonEncode(students.map((s) => s.toJson()).toList()),
      );

  Future<void> saveSelected(ParentStudent student) =>
      _storage.put<String>(_box, _selectedKey, jsonEncode(student.toJson()));

  Future<void> clear() => _storage.clearBox(_box);
}
