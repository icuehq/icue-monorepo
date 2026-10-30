import 'dart:developer';

import 'package:dio/dio.dart';

/// Interceptor that logs HTTP requests, responses, and errors.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({void Function(String message)? logPrint})
    : _logPrint = logPrint ?? _defaultLogPrint;

  final void Function(String message) _logPrint;

  static void _defaultLogPrint(String message) {
    log(message, name: 'ApiClient');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logPrint('[REQUEST] ${options.method.toUpperCase()} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final statusCode = response.statusCode != null
        ? '[${response.statusCode}]'
        : '[UNKNOWN]';
    _logPrint(
      '[RESPONSE] $statusCode ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final method = err.requestOptions.method.toUpperCase();
    final statusCode = err.response?.statusCode;
    if (statusCode != null) {
      _logPrint('[RESPONSE] [$statusCode] $method ${err.requestOptions.uri}');
    } else {
      final detail = err.message ?? err.type.name;
      _logPrint('[ERROR] $method ${err.requestOptions.uri} ($detail)');
    }
    handler.next(err);
  }
}
