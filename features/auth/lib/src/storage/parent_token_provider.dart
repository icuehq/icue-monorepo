import 'package:api_client/api_client.dart';
import 'package:auth/src/storage/parent_session_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// [TokenProvider] for the parent app. Registered as itself (not as
/// [TokenProvider]) so the admin provider stays the package default; the app
/// hands it to `ApiClient.setTokenProvider` at startup. No branch, org or zone
/// is injected: parent endpoints only expect `Source`.
@lazySingleton
class ParentTokenProvider implements TokenProvider {
  ParentTokenProvider(this._storage);

  final ParentSessionStorage _storage;

  /// Called after a 401 clears the session so the app can go to login.
  VoidCallback? onSessionExpired;

  @override
  Future<String?> getAccessToken() async => _storage.token;

  @override
  Future<bool> refreshToken() async => false;

  @override
  Future<void> onAuthFailed() async {
    await _storage.clear();
    onSessionExpired?.call();
  }

  @override
  dynamic getBranchId() => null;

  @override
  dynamic getOrganizationId() => null;

  @override
  dynamic getZoneId() => null;

  @override
  void invalidateSessionCache() {}
}
