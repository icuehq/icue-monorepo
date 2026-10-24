import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../storage/pref_service.dart';

@lazySingleton
class ApiClient {
  final Dio _dio;
  final PrefService _prefService;

  ApiClient(this._prefService) : _dio = Dio() {
    _dio.options.baseUrl = 'https://icuepro.com';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _prefService.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            options.headers['token'] = token; // Add both just in case
          }
          final sesid = _prefService.sesid;
          if (sesid != null) {
            options.headers['Sesid'] = sesid;
          }
          log('[REQUEST]: ${options.method} ${options.uri}');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          log(
            '[RESPONSE]: ${response.requestOptions.method} ${response.requestOptions.uri}',
          );

          return handler.next(response);
        },
        onError: (DioException e, handler) {
          log(
            '[ERROR]: ${e.response?.statusCode} ${e.requestOptions.uri} => ${e.response?.data}',
          );
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException {
      rethrow;
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException {
      rethrow;
    }
  }
}
