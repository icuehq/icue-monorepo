/// Abstract contract for retrieving and refreshing authentication tokens.
/// Each consumer app provides its own storage implementation (e.g. FlutterSecureStorage, SharedPreferences).
abstract class TokenProvider {
  /// Returns the current access token, or null if none is present.
  Future<String?> getAccessToken();

  /// Refreshes the access token using stored refresh credentials.
  /// Returns `true` if refresh succeeded, `false` otherwise.
  Future<bool> refreshToken();

  /// Called when an authentication failure occurs and the session cannot be restored.
  Future<void> onAuthFailed() async {}

  /// Current branch ID if available (used for injecting BranchId in non-GET requests).
  dynamic getBranchId() => null;

  /// Organization and zone of the signed-in user (injected in non-GET requests).
  dynamic getOrganizationId() => null;
  dynamic getZoneId() => null;

  /// Invalidate any in-memory cached session or branch data.
  void invalidateSessionCache() {}
}
