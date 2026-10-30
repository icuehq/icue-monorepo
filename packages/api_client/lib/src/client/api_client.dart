import 'dart:developer';

import 'package:api_client/src/auth/token_provider.dart';
import 'package:api_client/src/config/api_environment.dart';
import 'package:api_client/src/errors/api_exception.dart';
import 'package:api_client/src/interceptors/auth_interceptor.dart';
import 'package:api_client/src/interceptors/error_interceptor.dart';
import 'package:api_client/src/interceptors/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

/// Centralized API Client wrapping [Dio] for all icue apps,
/// enforcing session metadata injection, user-friendly error formatting,
/// and strongly-typed API exceptions.
class ApiClient {
  ApiClient({
    ApiEnvironment? environment,
    TokenProvider? tokenProvider,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 20),
    Duration receiveTimeout = const Duration(seconds: 20),
    bool enableLogging = true,
    void Function(String message)? logPrint,
    this.source = defaultSourceValue,
    this.branchIdProvider,
    this.onShowErrorMessage,
    this.onSessionExpired,
  }) : environment = environment ?? ApiEnvironment.fromEnvironment(),
       dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl:
                   '${(environment ?? ApiEnvironment.fromEnvironment()).baseUrl}/api',
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ) {
    _tokenProvider = tokenProvider;

    void expireSession() {
      invalidateSessionCache();
      onSessionExpired?.call();
    }

    _authInterceptor = AuthInterceptor(
      tokenProvider: _tokenProvider,
      dio: this.dio,
      source: source,
      branchIdProvider: () => currentBranchId,
      onSessionExpired: expireSession,
    );
    this.dio.interceptors.add(_authInterceptor);

    if (enableLogging) {
      this.dio.interceptors.add(
        LoggingInterceptor(logPrint: logPrint),
      );
    }

    this.dio.interceptors.add(ErrorInterceptor(
      onLogCrash: (path, error, stack, {fatal = true, message}) => log(
        'ERROR in $path: $message',
        name: 'ApiClient',
        error: error,
        stackTrace: stack,
      ),
      onShowErrorMessage: onShowErrorMessage,
      onSessionExpired: expireSession,
    ));
  }

  final Dio dio;
  final ApiEnvironment environment;
  final String source;
  final dynamic Function()? branchIdProvider;
  void Function(String message)? onShowErrorMessage;
  void Function()? onSessionExpired;

  TokenProvider? _tokenProvider;
  late final AuthInterceptor _authInterceptor;

  dynamic _cachedBranchId;

  TokenProvider? _resolveTokenProvider() {
    if (_tokenProvider != null) return _tokenProvider;
    if (GetIt.I.isRegistered<TokenProvider>()) {
      return GetIt.I<TokenProvider>();
    }
    return null;
  }

  /// Sets or updates the token provider used by the authentication interceptor.
  void setTokenProvider(TokenProvider provider) {
    _tokenProvider = provider;
    _authInterceptor.tokenProvider = provider;
  }

  /// Current active branch ID, resolved from cache, custom provider, or token provider.
  dynamic get currentBranchId {
    if (_cachedBranchId != null) return _cachedBranchId;
    _cachedBranchId =
        branchIdProvider?.call() ?? _resolveTokenProvider()?.getBranchId();
    return _cachedBranchId;
  }

  /// Clears in-memory session and branch cache on logout or credential change.
  void invalidateSessionCache() {
    _cachedBranchId = null;
    _resolveTokenProvider()?.invalidateSessionCache();
  }

  Future<Response<T>> _send<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          method: method,
          headers: {...?options?.headers, ...?headers},
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      // Surface the typed [ApiException] set by [ErrorInterceptor].
      final error = e.error;
      if (error is ApiException) throw error;
      rethrow;
    }
  }

  /// Sends a GET request and handles typed exception re-throwing.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    'GET',
    path,
    headers: headers,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  /// Sends a POST request and handles typed exception re-throwing.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    'POST',
    path,
    data: data,
    headers: headers,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  /// Sends a PUT request and handles typed exception re-throwing.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    'PUT',
    path,
    data: data,
    headers: headers,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  /// Sends a PATCH request and handles typed exception re-throwing.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    'PATCH',
    path,
    data: data,
    headers: headers,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  /// Sends a DELETE request and handles typed exception re-throwing.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _send<T>(
    'DELETE',
    path,
    data: data,
    headers: headers,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );
}
