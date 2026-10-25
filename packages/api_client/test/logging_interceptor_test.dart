import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

class _FakeRequestHandler extends RequestInterceptorHandler {
  RequestOptions? nextOptions;

  @override
  void next(RequestOptions requestOptions) {
    nextOptions = requestOptions;
  }
}

class _FakeResponseHandler extends ResponseInterceptorHandler {
  Response<dynamic>? nextResponse;

  @override
  void next(Response<dynamic> response) {
    nextResponse = response;
  }
}

class _FakeErrorHandler extends ErrorInterceptorHandler {
  DioException? nextErr;

  @override
  void next(DioException err) {
    nextErr = err;
  }
}

void main() {
  group('LoggingInterceptor', () {
    test('logs request method and URL on onRequest', () {
      final logs = <String>[];
      final interceptor = LoggingInterceptor(logPrint: logs.add);

      final options = RequestOptions(
        path: '/users',
        baseUrl: 'https://itraxpro.com/api',
        method: 'GET',
      );

      final handler = _FakeRequestHandler();
      interceptor.onRequest(options, handler);

      expect(logs, contains('[REQUEST] GET https://itraxpro.com/api/users'));
      expect(handler.nextOptions, equals(options));
    });

    test('logs response status code, method, and URL on onResponse', () {
      final logs = <String>[];
      final interceptor = LoggingInterceptor(logPrint: logs.add);

      final options = RequestOptions(
        path: '/auth/login',
        baseUrl: 'https://itraxpro.com/api',
        method: 'POST',
      );

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
      );

      final handler = _FakeResponseHandler();
      interceptor.onResponse(response, handler);

      expect(
        logs,
        contains('[RESPONSE] [200] POST https://itraxpro.com/api/auth/login'),
      );
      expect(handler.nextResponse, equals(response));
    });

    test('logs [UNKNOWN] when response status code is null', () {
      final logs = <String>[];
      final interceptor = LoggingInterceptor(logPrint: logs.add);

      final options = RequestOptions(
        path: '/test',
        baseUrl: 'https://itraxpro.com',
        method: 'GET',
      );

      final response = Response<dynamic>(requestOptions: options);

      final handler = _FakeResponseHandler();
      interceptor.onResponse(response, handler);

      expect(
        logs,
        contains('[RESPONSE] [UNKNOWN] GET https://itraxpro.com/test'),
      );
      expect(handler.nextResponse, equals(response));
    });

    test('logs response status code and URL on onError with response', () {
      final logs = <String>[];
      final interceptor = LoggingInterceptor(logPrint: logs.add);

      final options = RequestOptions(
        path: '/items/42',
        baseUrl: 'https://itraxpro.com/api',
        method: 'DELETE',
      );

      final err = DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse,
      );

      final handler = _FakeErrorHandler();
      interceptor.onError(err, handler);

      expect(
        logs,
        contains('[RESPONSE] [404] DELETE https://itraxpro.com/api/items/42'),
      );
      expect(handler.nextErr, equals(err));
    });

    test('logs error details when response is null on onError', () {
      final logs = <String>[];
      final interceptor = LoggingInterceptor(logPrint: logs.add);

      final options = RequestOptions(
        path: '/timeout',
        baseUrl: 'https://itraxpro.com/api',
        method: 'GET',
      );

      final err = DioException(
        requestOptions: options,
        message: 'Connection timed out',
        type: DioExceptionType.connectionTimeout,
      );

      final handler = _FakeErrorHandler();
      interceptor.onError(err, handler);

      expect(
        logs,
        contains(
          '[ERROR] GET https://itraxpro.com/api/timeout (Connection timed out)',
        ),
      );
      expect(handler.nextErr, equals(err));
    });

    test('uses default developer.log print without throwing', () {
      final interceptor = LoggingInterceptor();
      final options = RequestOptions(
        path: '/default',
        baseUrl: 'https://itraxpro.com',
        method: 'GET',
      );
      final reqHandler = _FakeRequestHandler();
      expect(() => interceptor.onRequest(options, reqHandler), returnsNormally);

      final resHandler = _FakeResponseHandler();
      expect(
        () => interceptor.onResponse(
          Response<dynamic>(requestOptions: options, statusCode: 200),
          resHandler,
        ),
        returnsNormally,
      );

      final errHandler = _FakeErrorHandler();
      expect(
        () => interceptor.onError(
          DioException(requestOptions: options),
          errHandler,
        ),
        returnsNormally,
      );
    });
  });

  group('ApiClient LoggingInterceptor integration', () {
    test('attaches LoggingInterceptor by default', () {
      final client = ApiClient();
      expect(
        client.dio.interceptors.any((i) => i is LoggingInterceptor),
        isTrue,
      );
    });

    test('does not attach LoggingInterceptor when enableLogging is false', () {
      final client = ApiClient(enableLogging: false);
      expect(
        client.dio.interceptors.any((i) => i is LoggingInterceptor),
        isFalse,
      );
    });

    test('passes custom logPrint to LoggingInterceptor', () {
      final logs = <String>[];
      final client = ApiClient(logPrint: logs.add);

      final loggingInterceptor = client.dio.interceptors
          .whereType<LoggingInterceptor>()
          .first;

      final handler = _FakeRequestHandler();
      loggingInterceptor.onRequest(
        RequestOptions(path: '/ping', baseUrl: 'https://itraxpro.com'),
        handler,
      );

      expect(logs, contains('[REQUEST] GET https://itraxpro.com/ping'));
      expect(handler.nextOptions, isNotNull);
    });
  });
}
