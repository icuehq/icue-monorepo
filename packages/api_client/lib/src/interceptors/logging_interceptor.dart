import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

/// Available logging presentation styles.
enum LoggingStyle {
  /// Standard modern log format: `[REQUEST] GET https://...`
  standard,

  /// Legacy icue log format matching the original application:
  /// `REQUEST[POST] => PATH: ... => BODY: ...`
  legacy,
}

/// Interceptor that logs HTTP requests, responses, and errors.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({
    void Function(String message)? logPrint,
    this.style = LoggingStyle.standard,
  }) : _logPrint = logPrint ?? _defaultLogPrint;

  final void Function(String message) _logPrint;
  final LoggingStyle style;

  static void _defaultLogPrint(String message) {
    log(message, name: 'ApiClient');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (style == LoggingStyle.legacy) {
      dynamic data = options.data;
      if (data is FormData) {
        data = Map.fromEntries(
          data.fields.map((f) => MapEntry(f.key, f.value)),
        );
      }
      String bodyStr;
      try {
        bodyStr = jsonEncode(data ?? {});
      } catch (_) {
        bodyStr = (data).toString();
      }
      _logPrint(
        'REQUEST[${options.method}] => PATH: ${options.baseUrl}${options.path} => BODY: $bodyStr',
      );
    } else {
      _logPrint('[REQUEST] ${options.method.toUpperCase()} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (style == LoggingStyle.legacy) {
      _logPrint(
        'RESPONSE[${response.statusCode}] => ${response.requestOptions.path}',
      );
    } else {
      final statusCode = response.statusCode != null
          ? '[${response.statusCode}]'
          : '[UNKNOWN]';
      _logPrint(
        '[RESPONSE] $statusCode ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (style == LoggingStyle.legacy) {
      _logPrint(
        'ERROR[${err.response?.statusCode}] => ${err.requestOptions.path}',
      );
    } else {
      final statusCode = err.response?.statusCode;
      if (statusCode != null) {
        _logPrint(
          '[RESPONSE] [$statusCode] ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri}',
        );
      } else {
        final detail = err.message ?? err.type.name;
        _logPrint(
          '[ERROR] ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri} ($detail)',
        );
      }
    }
    handler.next(err);
  }
}
