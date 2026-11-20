import 'package:icue_sdk/src/models/sdk_config.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds runtime session state and persists user data between app launches.
@singleton
class SessionService {
  static const String _deviceFcmTokenKey = 'icue_device_fcm_token';

  IcueSdkConfig? _config;
  String? _fcmToken;
  String? _identificationNo;
  String? _pendingIdentificationNo;
  int _sessionGeneration = 0;
  User? _user;

  String _getUserStorageKey(String id) {
    final user = _config?.apiUser ?? 'default';
    return 'icue_${user}_user_$id';
  }

  String _getActiveIdStorageKey() {
    final user = _config?.apiUser ?? 'default';
    return 'icue_${user}_active_id';
  }

  String _getRegisteredStudentsStorageKey() {
    final user = _config?.apiUser ?? 'default';
    return 'icue_${user}_registered_students';
  }

  /// Holds an identification number waiting to be opened once the navigator is ready.
  String? get pendingIdentificationNo => _pendingIdentificationNo;

  void setPendingIdentificationNo(String? id) {
    _pendingIdentificationNo = id;
  }

  void clearPendingIdentificationNo() {
    _pendingIdentificationNo = null;
  }

  /// Sets the active SDK configuration for the current session.
  void setConfig(IcueSdkConfig config) {
    _config = config;
  }

  IcueSdkConfig? get config => _config;

  /// Sets the device push notification token globally for this app installation.
  Future<void> setFcmToken(String token) async {
    _fcmToken = token;
    await _persistDeviceFcmToken(token);
  }

  /// The active device push token.
  String? get fcmToken => _fcmToken;

  /// Removes the device push token from memory and local persistence.
  Future<void> clearFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceFcmTokenKey);
    _fcmToken = null;
  }

  /// Updates the authenticated [user] for the active student and persists it.
  void setUser(User? user) {
    final activeId = _identificationNo;
    _user = user;
    if (activeId != null && activeId.isNotEmpty) {
      _persistUserForStudent(activeId, user);
    }
  }

  /// Updates the user specifically for [studentId] if it matches the current or given ID.
  void setUserForStudent(String studentId, User? user) {
    if (_identificationNo == studentId) {
      _user = user;
    }
    _persistUserForStudent(studentId, user);
  }

  /// Returns the in-memory or persisted [User] for [studentId].
  User? getUserForStudent(String studentId) {
    if (_identificationNo == studentId) {
      return _user;
    }
    return null;
  }

  /// Loads and returns the persisted [User] for [studentId] from local storage.
  Future<User?> loadUserForStudent(String studentId) async {
    if (_identificationNo == studentId && _user != null) {
      return _user;
    }
    final prefs = await SharedPreferences.getInstance();
    final userKey = _getUserStorageKey(studentId);
    final userStr = prefs.getString(userKey);
    return userStr != null ? userFromJson(userStr) : null;
  }

  /// The bearer token used for authenticated API requests.
  String? get token => _user?.token;

  User? get user => _user;

  String? get apiKey => _config?.apiKey;

  String? get apiUser => _config?.apiUser;

  String? get identificationNo => _identificationNo;

  /// Sets the active student identification number for API calls with concurrency safety.
  Future<void> setIdentificationNo(String id) async {
    final currentGen = ++_sessionGeneration;
    _identificationNo = id;
    _pendingIdentificationNo = null;

    final prefs = await SharedPreferences.getInstance();
    final activeKey = _getActiveIdStorageKey();
    await prefs.setString(activeKey, id);

    final userKey = _getUserStorageKey(id);
    final userStr = prefs.getString(userKey);
    final storedDeviceToken = prefs.getString(_deviceFcmTokenKey);

    // Guard: Discard stale async resolution if another student was selected during await
    if (currentGen != _sessionGeneration) return;

    _user = userStr != null ? userFromJson(userStr) : null;
    if (_fcmToken == null &&
        storedDeviceToken != null &&
        storedDeviceToken.isNotEmpty) {
      _fcmToken = storedDeviceToken;
    }
  }

  /// Restores the last active student identification number and cached session, if any.
  Future<void> restoreLastIdentificationNo() async {
    final prefs = await SharedPreferences.getInstance();
    final activeKey = _getActiveIdStorageKey();
    final lastId = prefs.getString(activeKey);
    if (lastId != null && lastId.isNotEmpty) {
      await setIdentificationNo(lastId);
    }
  }

  /// Restores any previously persisted session information for [id].
  Future<void> loadPersisted(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _getUserStorageKey(id);
    final userStr = prefs.getString(userKey);
    final storedDeviceToken = prefs.getString(_deviceFcmTokenKey);

    _user = userStr != null ? userFromJson(userStr) : null;
    if (_fcmToken == null &&
        storedDeviceToken != null &&
        storedDeviceToken.isNotEmpty) {
      _fcmToken = storedDeviceToken;
    }
  }

  /// Loads the device push token from local storage.
  Future<String?> loadPersistedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceFcmTokenKey);
  }

  /// Clears the active student session data without removing the device's push token.
  Future<void> clearSession() async {
    final activeId = _identificationNo;
    final prefs = await SharedPreferences.getInstance();
    if (activeId != null) {
      final userKey = _getUserStorageKey(activeId);
      await prefs.remove(userKey);
    }
    await prefs.remove(_getActiveIdStorageKey());
    _user = null;
    _identificationNo = null;
    _pendingIdentificationNo = null;
  }

  /// Tracks a student ID registered for push notifications.
  Future<void> addRegisteredStudent(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getRegisteredStudentsStorageKey();
    final list = prefs.getStringList(key) ?? <String>[];
    if (!list.contains(studentId)) {
      list.add(studentId);
      await prefs.setStringList(key, list);
    }
  }

  /// Removes a student ID from push notification tracking.
  Future<void> removeRegisteredStudent(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getRegisteredStudentsStorageKey();
    final list = prefs.getStringList(key) ?? <String>[];
    if (list.remove(studentId)) {
      await prefs.setStringList(key, list);
    }
  }

  /// Retrieves the list of all registered student IDs.
  Future<List<String>> getRegisteredStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getRegisteredStudentsStorageKey();
    return prefs.getStringList(key) ?? <String>[];
  }

  /// Clears the registered students list.
  Future<void> clearRegisteredStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getRegisteredStudentsStorageKey();
    await prefs.remove(key);
  }

  /// Clears all persistence including device tokens (primarily for test resets).
  Future<void> clearAllPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    if (_identificationNo != null) {
      final userKey = _getUserStorageKey(_identificationNo!);
      await prefs.remove(userKey);
    }
    await prefs.remove(_getActiveIdStorageKey());
    await clearRegisteredStudents();
    await clearFcmToken();
    _user = null;
    _identificationNo = null;
    _pendingIdentificationNo = null;
  }

  /// Persists or clears the serialized [user] in local storage for a specific student ID.
  Future<void> _persistUserForStudent(String studentId, User? user) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _getUserStorageKey(studentId);
    if (user == null) {
      await prefs.remove(userKey);
    } else {
      final json = userToJson(user);
      await prefs.setString(userKey, json);
    }
  }

  /// Persists the device push token globally.
  Future<void> _persistDeviceFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceFcmTokenKey, token);
  }
}
