import 'package:api_client/api_client.dart';
import 'package:auth/src/storage/user_local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Token provider backed by [UserLocalStorage] for persistence across app restarts.
@lazySingleton
class SessionTokenProvider implements TokenProvider {
  SessionTokenProvider(this._userLocalStorage) {
    _token = _userLocalStorage.getToken();
  }

  final UserLocalStorage _userLocalStorage;
  String? _token;

  /// Optional listener triggered when authentication fails (e.g. 401 unresolvable).
  VoidCallback? onSessionExpired;

  String? get currentToken => _token ?? _userLocalStorage.getToken();

  bool get isAuthenticated {
    final token = currentToken;
    return token != null && token.isNotEmpty;
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<void> clear() async {
    _token = null;
    await _userLocalStorage.clearUser();
  }

  @override
  Future<String?> getAccessToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }
    final user = await _userLocalStorage.getUserAsync();
    _token = user?.token;
    return _token;
  }

  @override
  Future<bool> refreshToken() async => false;

  @override
  Future<void> onAuthFailed() async {
    await clear();
    onSessionExpired?.call();
  }

  @override
  dynamic getBranchId() {
    return _userLocalStorage.getSelectedBranch()?.id ??
        _userLocalStorage.getUser()?.branchId;
  }

  @override
  void invalidateSessionCache() {
    _token = null;
  }
}

@module
abstract class AuthModule {
  @lazySingleton
  TokenProvider tokenProvider(SessionTokenProvider sessionProvider) =>
      sessionProvider;
}
