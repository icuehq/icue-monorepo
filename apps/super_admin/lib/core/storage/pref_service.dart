import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/embedding_request.dart';

@lazySingleton
class PrefService {
  final SharedPreferences _prefs;

  PrefService(this._prefs);

  static const String _keyToken = 'auth_token';
  static const String _keySesid = 'auth_sesid';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyOrgId = 'org_id';
  static const String _keyZoneId = 'zone_id';
  static const String _keyBranchId = 'branch_id';
  static const String _keyEmbeddingPrefix = 'student_embedding_';

  Future<void> saveSession({
    required String token,
    required String sesid,
    required int userId,
    required String userName,
    required int orgId,
    required int zoneId,
    required int branchId,
  }) async {
    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keySesid, sesid);
    await _prefs.setInt(_keyUserId, userId);
    await _prefs.setString(_keyUserName, userName);
    await _prefs.setInt(_keyOrgId, orgId);
    await _prefs.setInt(_keyZoneId, zoneId);
    await _prefs.setInt(_keyBranchId, branchId);
  }

  Future<void> saveOrgDetails({
    required int orgId,
    required int zoneId,
    required int branchId,
  }) async {
    await _prefs.setInt(_keyOrgId, orgId);
    await _prefs.setInt(_keyZoneId, zoneId);
    await _prefs.setInt(_keyBranchId, branchId);
  }

  String? get token => _prefs.getString(_keyToken);
  String? get sesid => _prefs.getString(_keySesid);
  int? get userId => _prefs.getInt(_keyUserId);
  String? get userName => _prefs.getString(_keyUserName);
  int? get orgId => _prefs.getInt(_keyOrgId);
  int? get zoneId => _prefs.getInt(_keyZoneId);
  int? get branchId => _prefs.getInt(_keyBranchId);

  bool get isLoggedIn => token != null && sesid != null;

  Future<void> saveStudentEmbedding(StudentEmbedding studentEmbedding) async {
    final jsonString = json.encode(studentEmbedding.toJson());
    await _prefs.setString(
      '$_keyEmbeddingPrefix${studentEmbedding.studentId}',
      jsonString,
    );
  }

  StudentEmbedding? getStudentEmbedding(int studentId) {
    final jsonString = _prefs.getString('$_keyEmbeddingPrefix$studentId');
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      return StudentEmbedding.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  List<StudentEmbedding> getAllStudentEmbeddings() {
    return _prefs
        .getKeys()
        .where((k) => k.startsWith(_keyEmbeddingPrefix))
        .map(
          (k) => getStudentEmbedding(
            int.tryParse(k.substring(_keyEmbeddingPrefix.length)) ?? -1,
          ),
        )
        .whereType<StudentEmbedding>()
        .toList();
  }

  bool hasStudentEmbedding(int studentId) {
    final key = '$_keyEmbeddingPrefix$studentId';
    return _prefs.containsKey(key) &&
        (_prefs.getString(key)?.isNotEmpty ?? false);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keySesid);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyUserName);
    await _prefs.remove(_keyOrgId);
    await _prefs.remove(_keyZoneId);
    await _prefs.remove(_keyBranchId);
  }
}
