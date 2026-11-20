import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_sdk/src/config/env.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:injectable/injectable.dart';

part 'api_error.dart';
part 'api_result.dart';
part 'api_routes.dart';

/// Constants used across API requests.
class ApiConstants {
  static const String apiSource = 'parentapp';
}

/// HTTP client wrapper around Dio with opinionated interceptors for auth,
/// payload shaping, token refresh, and debug logging.
@lazySingleton
class ApiClient {
  ApiClient(this._sessionService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: IcueEnv().baseConfig?.baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _tokenRefreshInterceptor = TokenRefreshInterceptor(_sessionService, _dio);
    _dio.interceptors.addAll([
      AuthInterceptor(_sessionService),
      PayloadInterceptor(),
      _tokenRefreshInterceptor,
      if (kDebugMode) LoggingInterceptor(),
    ]);
  }

  late final Dio _dio;
  final SessionService _sessionService;
  late final TokenRefreshInterceptor _tokenRefreshInterceptor;

  /// Registers a callback invoked after a successful 401 token refresh,
  /// so the caller can react (e.g. notify listeners of the updated session).
  set onTokenRefreshed(VoidCallback callback) {
    _tokenRefreshInterceptor.onTokenRefreshed = callback;
  }

  /// Performs a GET request and decodes the response to [T].
  ///
  /// Returns [ApiResult.cancel] — never throws — when [cancelToken] is fired.
  Future<ApiResult<T>> getJson<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(receiveDataWhenStatusError: true),
      );
      return ApiResult.success(
        _decode(response.data, decoder),
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return ApiResult.cancel();
      return ApiResult.failure(_mapDioError(e), e.response?.statusCode);
    } catch (e, stack) {
      log('getJson[$path] decode error', error: e, stackTrace: stack);
      return ApiResult.failure(
        ApiError.unknown(
          message: 'Failed to process response: ${e.toString()}',
        ),
        null,
      );
    }
  }

  /// Performs a POST request and decodes the response to [T].
  ///
  /// Returns [ApiResult.cancel] — never throws — when [cancelToken] is fired.
  Future<ApiResult<T>> postJson<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? decoder,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        cancelToken: cancelToken,
        options: Options(headers: headers, receiveDataWhenStatusError: true),
      );
      return ApiResult.success(
        _decode(response.data, decoder),
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return ApiResult.cancel();
      return ApiResult.failure(_mapDioError(e), e.response?.statusCode);
    } catch (e, stack) {
      log('postJson[$path] decode error', error: e, stackTrace: stack);
      return ApiResult.failure(
        ApiError.unknown(
          message: 'Failed to process response: ${e.toString()}',
        ),
        null,
      );
    }
  }

  /// Visible for unit testing error mapping logic.
  @visibleForTesting
  static ApiError mapDioErrorForTesting(DioException e) => _mapDioError(e);

  T _decode<T>(dynamic data, T Function(dynamic json)? decoder) {
    if (decoder != null) return decoder(data);
    return data as T;
  }
}

// ---------------------------------------------------------------------------
// Interceptors
// ---------------------------------------------------------------------------

/// Adds the bearer token and API key to every outbound request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionService);

  final SessionService _sessionService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _sessionService.token;
    if (token != null && token.isNotEmpty) {
      options.headers['token'] = token;
    }
    final apiKey = _sessionService.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      options.headers['APIKey'] = apiKey;
    }
    super.onRequest(options, handler);
  }
}

/// Injects the 'Source' field into every request payload.
class PayloadInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final data = options.data;
    if (data is Map) {
      options.data = {...data, 'Source': ApiConstants.apiSource};
    } else if (data == null) {
      options.data = {'Source': ApiConstants.apiSource};
    }
    super.onRequest(options, handler);
  }
}

/// Logs requests, responses, and non-cancelled errors in debug mode.
class LoggingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Cancellations are intentional — do not pollute the log.
    if (err.type != DioExceptionType.cancel) {
      log(
        'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}\nMESSAGE: ${err.message}',
      );
    }
    super.onError(err, handler);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final body = options.data is FormData
        ? 'FormData (not logged)'
        : jsonEncode(options.data);
    log('REQUEST[${options.method}] => PATH: ${options.uri}\nBODY: $body');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log(
      'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
    );
    super.onResponse(response, handler);
  }
}

/// Intercepts 401 responses, refreshes the token, and retries the original
/// request transparently. Extends [QueuedInterceptor] so concurrent 401s
/// are serialized — only one refresh executes at a time.
class TokenRefreshInterceptor extends QueuedInterceptor {
  TokenRefreshInterceptor(this._sessionService, this._dio) {
    // Dedicated Dio instance for the refresh call to avoid re-entering this
    // interceptor if the refresh endpoint itself returns 401.
    _refreshClient = Dio(
      BaseOptions(
        baseUrl: IcueEnv().baseConfig?.baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Called after a successful token refresh so the provider layer can
  /// propagate the updated session to listeners.
  VoidCallback? onTokenRefreshed;

  static const String _retriedKey = 'icueAuthRetried';

  Future<bool>? _activeRefreshFuture;
  final Dio _dio;
  late final Dio _refreshClient;
  final SessionService _sessionService;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    // Only intercept 401s that did not originate from the refresh endpoint
    // itself, ignore cancellations, and prevent infinite retry loops.
    if (err.type == DioExceptionType.cancel || alreadyRetried) {
      handler.next(err);
      return;
    }

    if (statusCode == 401 &&
        path != ApiRoutes.validateUserAuth &&
        path != ApiRoutes.removeRegTokens) {
      log('TokenRefresh: 401 on $path — attempting refresh');
      try {
        _activeRefreshFuture ??= _refreshToken();
        final refreshed = await _activeRefreshFuture!;
        _activeRefreshFuture = null;

        if (refreshed) {
          log('TokenRefresh: success — retrying $path');
          err.requestOptions.extra[_retriedKey] = true;
          final response = await _retry(err.requestOptions);
          handler.resolve(response);
          return;
        }
        log('TokenRefresh: refresh returned false — passing original 401');
      } catch (e, stack) {
        _activeRefreshFuture = null;
        log(
          'TokenRefresh: unexpected error during refresh',
          error: e,
          stackTrace: stack,
        );
      }
    }

    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    final apiUser = _sessionService.apiUser;
    final studentId = _sessionService.identificationNo;
    final apiKey = _sessionService.apiKey;

    if (apiUser == null || studentId == null) {
      log('TokenRefresh: skipped — apiUser or studentId is null');
      return false;
    }

    try {
      final response = await _refreshClient.post<dynamic>(
        ApiRoutes.validateUserAuth,
        data: {
          'APIUser': apiUser,
          'IdentificationNo': studentId,
          'Source': ApiConstants.apiSource,
        },
        options: Options(
          headers: {if (apiKey != null && apiKey.isNotEmpty) 'APIKey': apiKey},
        ),
      );

      if (response.statusCode == 200) {
        _sessionService
            .setUser(User.fromJson(response.data as Map<String, dynamic>));
        onTokenRefreshed?.call();
        return true;
      }

      log('TokenRefresh: server returned ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      log('TokenRefresh: network error [${e.response?.statusCode}]', error: e);
      return false;
    } catch (e, stack) {
      log('TokenRefresh: unexpected error', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    // Re-fetch through the main Dio instance so AuthInterceptor
    // automatically injects the newly refreshed token.
    return _dio.fetch(requestOptions);
  }
}

// ---------------------------------------------------------------------------
// Error mapping
// ---------------------------------------------------------------------------

/// Maps a [DioException] to a typed [ApiError].
///
/// Safe to call from any catch block — never throws.
ApiError _mapDioError(DioException e) {
  final status = e.response?.statusCode;

  // Extract a human-readable message from the response body safely.
  String? bodyMessage() {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      final msg = data['message'] ?? data['Message'] ?? data['error'];
      return msg?.toString();
    }
    return null;
  }

  final message = bodyMessage() ?? e.message ?? 'Unknown error';

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ApiError.network(message: 'Request timed out');

    case DioExceptionType.connectionError:
      return ApiError.network(message: 'No internet connection');

    case DioExceptionType.cancel:
      // Should not reach here — callers guard against cancel before calling
      // _mapDioError, but handle it defensively.
      return ApiError.cancelled();

    case DioExceptionType.badResponse:
      if (status == 401) {
        return ApiError.unauthorized(message: message, statusCode: status);
      }
      if (status == 404) {
        return ApiError.notFound(message: message);
      }
      if (status != null && status >= 500) {
        return ApiError.server(message: message, statusCode: status);
      }
      return ApiError.unknown(message: message, statusCode: status);

    case DioExceptionType.badCertificate:
      return ApiError.network(message: 'Certificate verification failed');

    case DioExceptionType.unknown:
      return ApiError.unknown(message: message, statusCode: status);
  }
}
