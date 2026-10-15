import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../models/user_info.dart';
import '../utils/app_utils.dart';
import '../utils/navigation/app_router.dart';
import 'crashlytics_service.dart';
import 'hive_service.dart';

/// Abstract base class for API clients providing common Dio configuration,
/// request/response interceptors, authentication header injection, centralized
/// error handling, 401 unauthorized session clearing, and Crashlytics tracking.
abstract class BaseApiClient {
  BaseApiClient({required this.crashlytics, Dio? dio})
    : dio = dio ?? createDio() {
    this.dio.options.baseUrl = baseUrl;
    this.dio.interceptors.add(_createInterceptor());
  }

  final Dio dio;
  final CrashlyticsService crashlytics;

  /// The base URL for this specific API client.
  String get baseUrl;

  /// Friendly identifier used for logging and crash tracking.
  String get clientName => runtimeType.toString();

  /// Additional fields to inject into non-GET request bodies/forms.
  /// Subclasses can override this to inject service-specific fields (e.g. Source, BranchId).
  Map<String, dynamic>? getExtraRequestData() => null;

  /// List of URL subpaths that should NOT trigger a UI error toast/snackbar when failing.
  List<String> get errorExemptPaths => const [];

  /// Factory to create a default configured Dio instance.
  static Dio createDio({BaseOptions? options}) {
    return Dio(
      options ??
          BaseOptions(
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
    );
  }

  InterceptorsWrapper _createInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final isAuthEndpoint =
            options.path.contains('login') ||
            options.path.contains('getloginotp');

        if (!isAuthEndpoint) {
          final user = currentUser;
          if (user != null) {
            options.headers['token'] = user.token;
          }
        }

        // Only inject extra fields for requests that allow data.
        if (options.method != 'GET') {
          final extraFields = getExtraRequestData();
          if (extraFields != null && extraFields.isNotEmpty) {
            final cleanedExtra = Map<String, dynamic>.from(extraFields)
              ..removeWhere((_, v) => v == null);

            if (options.data is Map) {
              options.data = {...cleanedExtra, ...(options.data as Map)};
            } else if (options.data is FormData) {
              final formData = options.data as FormData;
              final existingFields = {
                for (var f in formData.fields) f.key: f.value,
              };

              cleanedExtra.forEach((key, value) {
                if (!existingFields.containsKey(key)) {
                  formData.fields.add(MapEntry(key, value.toString()));
                }
              });
              options.data = formData;
            } else {
              options.data ??= cleanedExtra;
            }
          }
        }

        _logRequest(options);
        handler.next(options);
      },

      onResponse: (response, handler) {
        if (kDebugMode) {
          log(
            '[$clientName] RESPONSE[${response.statusCode}] => ${response.requestOptions.path}',
          );
        }
        handler.next(response);
      },

      onError: (error, handler) async {
        final path = error.requestOptions.path;
        if (kDebugMode) {
          log(
            '[$clientName] ERROR[${error.response?.statusCode}] => $path'
            '${error.response?.data != null ? " => DATA: ${error.response?.data}" : ""}',
          );
        }

        final isExempt = errorExemptPaths.any(
          (exempt) => path.contains(exempt),
        );
        if (isExempt) {
          handler.next(error);
          return;
        }

        final isConnError = isConnectionError(error);
        final message = extractErrorMessage(error);

        if (navigatorKey.currentContext != null) {
          AppUtils.showErrorMessage(navigatorKey.currentContext!, message);
        }

        final statusCode = error.response?.statusCode;
        final isAuthOrValidationError =
            statusCode == 401 ||
            statusCode == 400 ||
            statusCode == 403 ||
            statusCode == 422 ||
            path.contains('login') ||
            path.contains('getloginotp');

        final isBadResponse = error.type == DioExceptionType.badResponse;
        if (!isAuthOrValidationError && !isConnError) {
          logCrash(
            path,
            error,
            error.stackTrace,
            fatal: !isBadResponse,
            message: message,
          );
        }

        if (error.response?.statusCode == 401) {
          invalidateSessionCache();
          await HiveService.clearAll();
          final ctx = navigatorKey.currentContext;
          if (ctx != null) ctx.go('/login');
        }

        handler.next(error);
      },
    );
  }

  // --- Public HTTP Methods ---

  // --- Public HTTP Methods ---

  Future<Response> get(String path) => dio.get(path);

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) => dio.post(
    path,
    data: data,
    options: headers != null ? Options(headers: headers) : null,
  );

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) => dio.put(
    path,
    data: data,
    options: headers != null ? Options(headers: headers) : null,
  );

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) => dio.delete(
    path,
    data: data,
    options: headers != null ? Options(headers: headers) : null,
  );

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) => dio.patch(
    path,
    data: data,
    options: headers != null ? Options(headers: headers) : null,
  );

  /// Advanced request method for custom options, cancel tokens, query parameters, etc.
  Future<Response<T>> request<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => dio.request<T>(
    path,
    data: data,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
    options: options,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  // --- Error Handling & Helpers ---

  String? handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Unable to connect to the server. Please check your internet connection and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out sending data to the server. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond. Please try again later.';
      case DioExceptionType.badCertificate:
        return 'The server certificate is invalid. Please contact support.';
      case DioExceptionType.badResponse:
        return 'Received an invalid response from the server.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.connectionError:
        final errorMessage = error.message ?? '';
        if (errorMessage.contains('Failed host lookup') ||
            errorMessage.contains('nodename nor servname')) {
          return 'Unable to reach the server. Please check your internet connection and ensure the server is accessible.';
        }
        return 'Network error occurred. Please check your internet connection and try again.';
      case DioExceptionType.unknown:
        final errorMessage = error.message ?? '';
        if (errorMessage.contains('Failed host lookup') ||
            errorMessage.contains('nodename nor servname') ||
            errorMessage.contains('connection')) {
          return 'Unable to connect to the server. Please check your internet connection.';
        }
        return null;
      case DioExceptionType.transformTimeout:
        return 'Request timed out processing data. Please try again.';
    }
  }

  bool isConnectionError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.type == DioExceptionType.unknown &&
            (error.message?.contains('Failed host lookup') == true ||
                error.message?.contains('nodename nor servname') == true ||
                error.message?.contains('connection') == true));
  }

  void logCrash(
    String from,
    Object error,
    StackTrace? stack, {
    bool fatal = true,
    String? message,
  }) {
    if (kIsWeb) return;

    log('[$clientName] ERROR in $from: $message', error: error);

    final user = currentUser;
    crashlytics.recordError(
      error,
      stack,
      fatal: fatal,
      reason: message,
      information: [
        {
          'from': from,
          'client': clientName,
          'user': user != null
              ? {
                  'Id': user.id,
                  'OrganizationId': user.organizationId,
                  'ZoneId': user.zoneId,
                  'BranchId': user.branchId,
                  'SchoolName': user.schoolName,
                  'Role': user.roles.map((r) => r.toJson()).toList(),
                }
              : null,
        },
      ],
    );
  }

  String extractErrorMessage(DioException error) {
    if (isConnectionError(error)) {
      final connectionMsg = handleError(error);
      if (connectionMsg != null) {
        return connectionMsg;
      }
    }

    final data = error.response?.data;
    String msg = '';
    if (data is String) {
      msg = data;
    } else if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (data is Map && data['error'] != null) {
      msg = data['error'].toString();
    } else {
      msg = error.message ?? handleError(error) ?? 'Unexpected error occurred.';
    }

    return msg.contains('<!DOCTYPE html>') ? 'Something went wrong...' : msg;
  }

  void _logRequest(RequestOptions options) {
    if (!kDebugMode) return;
    dynamic data = options.data;
    if (data is FormData) {
      data = Map.fromEntries(data.fields.map((f) => MapEntry(f.key, f.value)));
    }

    log(
      '[$clientName] REQUEST[${options.method}] => PATH: ${options.baseUrl}${options.path} => BODY: '
      '${jsonEncode(data ?? {})}',
    );
  }

  /// Clear in-memory session cache on logout or credential change.
  /// Retained for backward compatibility; state is fetched dynamically from [HiveService].
  void invalidateSessionCache() {}

  /// The currently authenticated user, fetched dynamically from in-memory Hive storage.
  UserInfo? get currentUser {
    try {
      return HiveService.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// The currently active branch ID (either selected zonal branch or user's assigned branch).
  dynamic get currentBranchId {
    try {
      return HiveService.currentZonalBranch?.id ?? currentUser?.branchId;
    } catch (_) {
      return currentUser?.branchId;
    }
  }
}
