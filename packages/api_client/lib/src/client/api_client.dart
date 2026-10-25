import 'dart:convert';
import 'dart:developer';

import 'package:api_client/src/auth/token_provider.dart';
import 'package:api_client/src/config/api_environment.dart';
import 'package:api_client/src/errors/api_exception.dart';
import 'package:api_client/src/errors/error_helpers.dart';
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
    List<Interceptor> additionalInterceptors = const [],
    Duration connectTimeout = const Duration(seconds: 20),
    Duration receiveTimeout = const Duration(seconds: 20),
    BaseOptions? customBaseOptions,
    bool enableLogging = true,
    void Function(String message)? logPrint,
    LoggingStyle loggingStyle = LoggingStyle.standard,
    this.source = defaultSourceValue,
    this.branchIdProvider,
    this.onShowErrorMessage,
    this.onSessionExpired,
  }) : environment = environment ?? ApiEnvironment.fromEnvironment(),
       dio =
           dio ??
           Dio(
             customBaseOptions ??
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

    _authInterceptor = AuthInterceptor(
      tokenProvider: _tokenProvider,
      dio: this.dio,
      source: source,
      branchIdProvider: () => currentBranchId,
      onSessionExpired: () {
        invalidateSessionCache();
        onSessionExpired?.call();
      },
    );
    this.dio.interceptors.add(_authInterceptor);

    if (enableLogging) {
      this.dio.interceptors.add(
        LoggingInterceptor(
          logPrint: logPrint,
          style: loggingStyle,
        ),
      );
    }

    _errorInterceptor = ErrorInterceptor(
      onLogCrash: (path, error, stack, {fatal = true, message}) {
        logCrash(path, error, stack, fatal: fatal, message: message);
      },
      onShowErrorMessage: onShowErrorMessage,
      onSessionExpired: () {
        invalidateSessionCache();
        onSessionExpired?.call();
      },
      onInvalidateSession: invalidateSessionCache,
    );
    this.dio.interceptors.add(_errorInterceptor);

    if (additionalInterceptors.isNotEmpty) {
      this.dio.interceptors.addAll(additionalInterceptors);
    }
  }

  final Dio dio;
  final ApiEnvironment environment;
  final String source;
  final dynamic Function()? branchIdProvider;
  void Function(String message)? onShowErrorMessage;
  void Function()? onSessionExpired;

  TokenProvider? _tokenProvider;
  late final AuthInterceptor _authInterceptor;
  late final ErrorInterceptor _errorInterceptor;

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

  /// Classifies error and returns user-friendly error message.
  String? handleError(DioException error) => ErrorHelpers.handleError(error);

  /// Determines if the error is a connection or network error.
  bool isConnectionError(DioException error) =>
      ErrorHelpers.isConnectionError(error);

  /// Extracts error message from response body or falls back to user-friendly network message.
  String extractErrorMessage(DioException error) =>
      ErrorHelpers.extractErrorMessage(error);

  /// Logs error details matching legacy application conventions.
  void logCrash(
    String from,
    Object error,
    StackTrace? stack, {
    bool fatal = true,
    String? message,
  }) {
    final logMessage = 'ERROR in $from: $message';
    log(logMessage, name: 'ApiClient', error: error, stackTrace: stack);
  }

  /// Formats and logs request details matching legacy application conventions.
  void logRequest(RequestOptions options) {
    dynamic data = options.data;
    if (data is FormData) {
      data = Map<String, dynamic>.fromEntries(
        data.fields.map((f) => MapEntry<String, dynamic>(f.key, f.value)),
      );
    }

    String bodyStr;
    try {
      bodyStr = jsonEncode(data ?? <String, dynamic>{});
    } catch (_) {
      bodyStr = (data ?? const <String, dynamic>{}).toString();
    }

    log(
      'REQUEST[${options.method}] => PATH: ${options.baseUrl}${options.path} => BODY: $bodyStr',
      name: 'ApiClient',
    );
  }

  /// Sends a GET request and handles typed exception re-throwing.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    options ??= Options();
    if (headers != null) {
      options.headers = {...?options.headers, ...headers};
    }
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapApiException(e);
    }
  }

  /// Sends a POST request and handles typed exception re-throwing.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    options ??= Options();
    if (headers != null) {
      options.headers = {...?options.headers, ...headers};
    }
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapApiException(e);
    }
  }

  /// Sends a PUT request and handles typed exception re-throwing.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    options ??= Options();
    if (headers != null) {
      options.headers = {...?options.headers, ...headers};
    }
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapApiException(e);
    }
  }

  /// Sends a PATCH request and handles typed exception re-throwing.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    options ??= Options();
    if (headers != null) {
      options.headers = {...?options.headers, ...headers};
    }
    try {
      return await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapApiException(e);
    }
  }

  /// Sends a DELETE request and handles typed exception re-throwing.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    options ??= Options();
    if (headers != null) {
      options.headers = {...?options.headers, ...headers};
    }
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _unwrapApiException(e);
    }
  }

  Exception _unwrapApiException(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return e;
  }
}
