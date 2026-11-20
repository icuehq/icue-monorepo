import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'school_config.dart';

/// Represents an active signed-in student session with their school configuration.
class UserSession {
  const UserSession({required this.school, required this.studentId});

  final SchoolConfig school;
  final String studentId;

  Map<String, dynamic> toJson() {
    return {'school': school.toJson(), 'studentId': studentId};
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      school: SchoolConfig.fromJson(
        Map<String, dynamic>.from(json['school'] as Map),
      ),
      studentId: json['studentId'] as String? ?? '',
    );
  }
}

/// Helper class to manage local persistence for user sessions and custom schools.
class SessionManager {
  static const String _sessionKey = 'icue_example_user_session';
  static const String _customSchoolsKey = 'icue_example_custom_schools';

  /// Saves the current user session locally in [SharedPreferences].
  static Future<void> saveSession({
    required SchoolConfig school,
    required String studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final session = UserSession(school: school, studentId: studentId);
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  /// Retrieves the saved user session if one exists.
  static Future<UserSession?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStr = prefs.getString(_sessionKey);
      if (sessionStr == null || sessionStr.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(sessionStr) as Map<String, dynamic>;
      return UserSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved user session on logout.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Retrieves any custom schools added by the user.
  static Future<List<SchoolConfig>> getCustomSchools() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customListStr = prefs.getStringList(_customSchoolsKey);
      if (customListStr == null) return [];
      return customListStr
          .map(
            (s) => SchoolConfig.fromJson(jsonDecode(s) as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a new custom school configuration locally.
  static Future<void> saveCustomSchool(SchoolConfig school) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getCustomSchools();
      current.removeWhere((s) => s.id == school.id);
      current.add(school);
      final rawList = current.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_customSchoolsKey, rawList);
    } catch (_) {}
  }
}
