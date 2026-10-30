import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

void main() {
  group('ApiEnvironment', () {
    test('dev has correct base URL and flags', () {
      expect(ApiEnvironment.dev.baseUrl, equals('https://itraxpro.com'));
      expect(ApiEnvironment.dev.isDev, isTrue);
      expect(ApiEnvironment.dev.isProd, isFalse);
    });

    test('prod has correct base URL and flags', () {
      expect(ApiEnvironment.prod.baseUrl, equals('https://icuepro.com'));
      expect(ApiEnvironment.prod.isProd, isTrue);
      expect(ApiEnvironment.prod.isDev, isFalse);
    });

    test('fromEnvironment defaults to dev', () {
      expect(ApiEnvironment.fromEnvironment(), equals(ApiEnvironment.dev));
    });
  });

  group('ApiClient', () {
    test('initializes with dev baseUrl by default', () {
      final client = ApiClient();
      expect(client.environment, equals(ApiEnvironment.dev));
      expect(client.dio.options.baseUrl, equals('https://itraxpro.com/api'));
    });

    test('initializes with explicit prod environment', () {
      final client = ApiClient(environment: ApiEnvironment.prod);
      expect(client.environment, equals(ApiEnvironment.prod));
      expect(client.dio.options.baseUrl, equals('https://icuepro.com/api'));
    });

    test('attaches ErrorInterceptor by default', () {
      final client = ApiClient();
      expect(client.dio.interceptors.any((i) => i is ErrorInterceptor), isTrue);
    });

    test('resolves and caches currentBranchId', () {
      final client = ApiClient(
        tokenProvider: _MockTokenProvider('token', branchId: 101),
      );
      expect(client.currentBranchId, equals(101));

      // After invalidateSessionCache, it refreshes
      client.invalidateSessionCache();
      expect(client.currentBranchId, equals(101));
    });
  });

  group('ApiException user-friendly default messages', () {
    test('NetworkException has user-friendly message', () {
      const exception = NetworkException();
      expect(
        exception.message,
        equals('Unable to connect. Please check your internet connection.'),
      );
    });

    test('BadRequestException has user-friendly message', () {
      const exception = BadRequestException();
      expect(
        exception.message,
        equals('Invalid request. Please check your details and try again.'),
      );
    });

    test('ServerException has user-friendly message', () {
      const exception = ServerException();
      expect(
        exception.message,
        equals(
          'Our servers are temporarily unavailable. Please try again shortly.',
        ),
      );
    });

    test('UnknownApiException has user-friendly message', () {
      const exception = UnknownApiException();
      expect(
        exception.message,
        equals('Something went wrong. Please try again.'),
      );
    });
  });

  group('ErrorInterceptor 401 login handling', () {
    final interceptor = ErrorInterceptor();

    test('maps 401 on /api/v1.0/login with "un authorized" to friendly OTP message', () {
      DioException? interceptedError;
      final handler = _TestErrorHandler((err) => interceptedError = err);

      final dioErr = DioException(
        requestOptions: RequestOptions(
          path: '/api/v1.0/login',
          baseUrl: 'https://itraxpro.com',
          method: 'POST',
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/login'),
          statusCode: 401,
          data: 'un authorized',
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(dioErr, handler);

      expect(interceptedError, isNotNull);
      expect(interceptedError!.error, isA<UnauthorizedException>());
      expect(
        (interceptedError!.error as UnauthorizedException).message,
        equals('Invalid OTP. Please check and try again.'),
      );
    });

    test('maps 401 on /api/v1.0/login with json "Unauthorized" to friendly OTP message', () {
      DioException? interceptedError;
      final handler = _TestErrorHandler((err) => interceptedError = err);

      final dioErr = DioException(
        requestOptions: RequestOptions(
          path: '/api/v1.0/login',
          baseUrl: 'https://itraxpro.com',
          method: 'POST',
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/login'),
          statusCode: 401,
          data: <String, dynamic>{'message': 'Unauthorized'},
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(dioErr, handler);

      expect(interceptedError, isNotNull);
      expect(interceptedError!.error, isA<UnauthorizedException>());
      expect(
        (interceptedError!.error as UnauthorizedException).message,
        equals('Invalid OTP. Please check and try again.'),
      );
    });

    test('preserves specific non-generic 401 message on login endpoint', () {
      DioException? interceptedError;
      final handler = _TestErrorHandler((err) => interceptedError = err);

      final dioErr = DioException(
        requestOptions: RequestOptions(
          path: '/api/v1.0/login',
          baseUrl: 'https://itraxpro.com',
          method: 'POST',
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/login'),
          statusCode: 401,
          data: <String, dynamic>{
            'message': 'Account is temporarily suspended',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(dioErr, handler);

      expect(interceptedError, isNotNull);
      expect(interceptedError!.error, isA<UnauthorizedException>());
      expect(
        (interceptedError!.error as UnauthorizedException).message,
        equals('Account is temporarily suspended'),
      );
    });

    test('uses standard session expired message on non-login 401', () {
      DioException? interceptedError;
      final handler = _TestErrorHandler((err) => interceptedError = err);

      final dioErr = DioException(
        requestOptions: RequestOptions(
          path: '/api/v1.0/profile',
          baseUrl: 'https://itraxpro.com',
          method: 'GET',
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/profile'),
          statusCode: 401,
          data: 'un authorized',
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(dioErr, handler);

      expect(interceptedError, isNotNull);
      expect(interceptedError!.error, isA<UnauthorizedException>());
      expect(
        (interceptedError!.error as UnauthorizedException).message,
        equals('un authorized'),
      );
    });
  });

  group('AuthInterceptor token headers & extra fields injection', () {
    test('attaches token header when token is available', () async {
      final tokenProvider = _MockTokenProvider('sample-jwt-token');
      final client = ApiClient(tokenProvider: tokenProvider);

      RequestOptions? interceptedOptions;
      final interceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: client.dio,
      );
      final handler = _TestRequestHandler(
        (options) => interceptedOptions = options,
      );

      await interceptor.onRequest(
        RequestOptions(path: '/api/v1.0/getBranchesByZoneId'),
        handler,
      );

      expect(interceptedOptions, isNotNull);
      expect(interceptedOptions!.headers['token'], equals('sample-jwt-token'));
      expect(interceptedOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('skips attaching token when request has no_auth extra', () async {
      final tokenProvider = _MockTokenProvider('sample-jwt-token');
      final client = ApiClient(tokenProvider: tokenProvider);
      final interceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: client.dio,
      );

      RequestOptions? interceptedOptions;
      final handler = _TestRequestHandler(
        (options) => interceptedOptions = options,
      );

      await interceptor.onRequest(
        RequestOptions(
          path: '/api/v2.0/login',
          extra: <String, dynamic>{'no_auth': true},
        ),
        handler,
      );

      expect(interceptedOptions, isNotNull);
      expect(interceptedOptions!.headers.containsKey('token'), isFalse);
    });

    test(
      'injects Source and BranchId into Map body on non-GET request',
      () async {
        final tokenProvider = _MockTokenProvider('sample-token', branchId: 427);
        final client = ApiClient(tokenProvider: tokenProvider);
        final interceptor = AuthInterceptor(
          tokenProvider: tokenProvider,
          dio: client.dio,
          branchIdProvider: () => 427,
        );

        RequestOptions? interceptedOptions;
        final handler = _TestRequestHandler(
          (options) => interceptedOptions = options,
        );

        await interceptor.onRequest(
          RequestOptions(
            path: '/api/v1.0/getActionsByRole',
            method: 'POST',
            data: <String, dynamic>{'existingKey': 'existingValue'},
          ),
          handler,
        );

        expect(interceptedOptions, isNotNull);
        final data = interceptedOptions!.data as Map;
        expect(data['Source'], equals('adminapp'));
        expect(data['BranchId'], equals(427));
        expect(data['existingKey'], equals('existingValue'));
      },
    );

    test('injects Source and BranchId when data is initially null', () async {
      final tokenProvider = _MockTokenProvider('sample-token', branchId: 427);
      final client = ApiClient(tokenProvider: tokenProvider);
      final interceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: client.dio,
        branchIdProvider: () => 427,
      );

      RequestOptions? interceptedOptions;
      final handler = _TestRequestHandler(
        (options) => interceptedOptions = options,
      );

      await interceptor.onRequest(
        RequestOptions(path: '/api/v1.0/getActionsByRole', method: 'POST'),
        handler,
      );

      expect(interceptedOptions, isNotNull);
      final data = interceptedOptions!.data as Map;
      expect(data['Source'], equals('adminapp'));
      expect(data['BranchId'], equals(427));
    });

    test(
      'injects Source and BranchId into FormData body on non-GET request',
      () async {
        final tokenProvider = _MockTokenProvider('sample-token', branchId: 427);
        final client = ApiClient(tokenProvider: tokenProvider);
        final interceptor = AuthInterceptor(
          tokenProvider: tokenProvider,
          dio: client.dio,
          branchIdProvider: () => 427,
        );

        final formData = FormData.fromMap({'name': 'John'});
        RequestOptions? interceptedOptions;
        final handler = _TestRequestHandler(
          (options) => interceptedOptions = options,
        );

        await interceptor.onRequest(
          RequestOptions(
            path: '/api/v1.0/upload',
            method: 'POST',
            data: formData,
          ),
          handler,
        );

        expect(interceptedOptions, isNotNull);
        final returnedFormData = interceptedOptions!.data as FormData;
        final fieldMap = {
          for (final f in returnedFormData.fields) f.key: f.value,
        };
        expect(fieldMap['Source'], equals('adminapp'));
        expect(fieldMap['BranchId'], equals('427'));
        expect(fieldMap['name'], equals('John'));
      },
    );

    test('does NOT inject Source or BranchId on GET request', () async {
      final tokenProvider = _MockTokenProvider('sample-token', branchId: 427);
      final client = ApiClient(tokenProvider: tokenProvider);
      final interceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: client.dio,
        branchIdProvider: () => 427,
      );

      RequestOptions? interceptedOptions;
      final handler = _TestRequestHandler(
        (options) => interceptedOptions = options,
      );

      await interceptor.onRequest(
        RequestOptions(path: '/api/v1.0/getDetails', method: 'GET'),
        handler,
      );

      expect(interceptedOptions, isNotNull);
      expect(interceptedOptions!.data, isNull);
    });

    test('omits BranchId when null and only injects Source', () async {
      final tokenProvider = _MockTokenProvider('sample-token');
      final client = ApiClient(tokenProvider: tokenProvider);
      final interceptor = AuthInterceptor(
        tokenProvider: tokenProvider,
        dio: client.dio,
        branchIdProvider: () => null,
      );

      RequestOptions? interceptedOptions;
      final handler = _TestRequestHandler(
        (options) => interceptedOptions = options,
      );

      await interceptor.onRequest(
        RequestOptions(
          path: '/api/v2.0/login',
          method: 'POST',
          data: <String, dynamic>{'username': 'admin'},
        ),
        handler,
      );

      expect(interceptedOptions, isNotNull);
      final data = interceptedOptions!.data as Map;
      expect(data['Source'], equals('adminapp'));
      expect(data.containsKey('BranchId'), isFalse);
    });

    test(
      'setTokenProvider dynamically updates token provider on client',
      () async {
        final client = ApiClient();
        final tokenProvider = _MockTokenProvider('dynamic-token');
        client.setTokenProvider(tokenProvider);

        RequestOptions? interceptedOptions;
        final handler = _TestRequestHandler(
          (options) => interceptedOptions = options,
        );

        final authInterceptor = client.dio.interceptors
            .whereType<AuthInterceptor>()
            .first;
        await authInterceptor.onRequest(RequestOptions(path: '/test'), handler);

        expect(interceptedOptions, isNotNull);
        expect(interceptedOptions!.headers['token'], equals('dynamic-token'));
        expect(
          interceptedOptions!.headers.containsKey('Authorization'),
          isFalse,
        );
      },
    );
  });

  group('Old app error rules in ErrorInterceptor and ErrorHelpers', () {
    test('bypasses error handling for getDriverDocs and getVehicleDocs', () {
      bool crashLogged = false;
      bool errorShown = false;
      final interceptor = ErrorInterceptor(
        onLogCrash: (_, _, _, {fatal = true, message}) => crashLogged = true,
        onShowErrorMessage: (_) => errorShown = true,
      );

      DioException? nextErr;
      final handler = _TestErrorHandler((err) => nextErr = err);

      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api/v1.0/getDriverDocs'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/getDriverDocs'),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(dioErr, handler);

      expect(nextErr, equals(dioErr));
      expect(crashLogged, isFalse);
      expect(errorShown, isFalse);
    });

    test('classifies connection errors and formats user-friendly messages', () {
      final timeoutErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(ErrorHelpers.isConnectionError(timeoutErr), isTrue);
      expect(
        ErrorHelpers.handleError(timeoutErr),
        equals(
          'Unable to connect to the server. Please check your internet connection and try again.',
        ),
      );

      final hostLookupErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
        message: 'Failed host lookup: itraxpro.com',
      );
      expect(ErrorHelpers.isConnectionError(hostLookupErr), isTrue);
      expect(
        ErrorHelpers.handleError(hostLookupErr),
        equals(
          'Unable to reach the server. Please check your internet connection and ensure the server is accessible.',
        ),
      );
    });

    test('extractErrorMessage falls back to "Something went wrong..." for HTML pages', () {
      final htmlErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 502,
          data: '<!DOCTYPE html><html><body>Bad Gateway</body></html>',
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        ErrorHelpers.extractErrorMessage(htmlErr),
        equals('Something went wrong...'),
      );
    });

    test('skips crash logging for auth and validation errors (400, 401, 403, 422, login)', () {
      bool crashLogged = false;
      final interceptor = ErrorInterceptor(
        onLogCrash: (_, _, _, {fatal = true, message}) => crashLogged = true,
      );

      for (final code in [400, 401, 403, 422]) {
        crashLogged = false;
        final err = DioException(
          requestOptions: RequestOptions(path: '/api/v1.0/resource'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/api/v1.0/resource'),
            statusCode: code,
          ),
          type: DioExceptionType.badResponse,
        );
        interceptor.onError(err, _TestErrorHandler((_) {}));
        expect(
          crashLogged,
          isFalse,
          reason: 'Status code $code should not be logged',
        );
      }
    });

    test('reports unexpected 500 error with non-fatal flag', () {
      bool crashLogged = false;
      bool wasFatal = true;
      String? reportedMessage;

      final interceptor = ErrorInterceptor(
        onLogCrash: (path, error, stack, {fatal = true, message}) {
          crashLogged = true;
          wasFatal = fatal;
          reportedMessage = message;
        },
      );

      final err = DioException(
        requestOptions: RequestOptions(path: '/api/v1.0/payments'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/payments'),
          statusCode: 500,
          data: <String, dynamic>{
            'message': 'Database connection pool exhausted',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(err, _TestErrorHandler((_) {}));

      expect(crashLogged, isTrue);
      expect(wasFatal, isFalse); // badResponse is non-fatal
      expect(reportedMessage, equals('Database connection pool exhausted'));
    });

    test('triggers onShowErrorMessage and onSessionExpired callbacks', () {
      String? shownMessage;
      bool sessionExpiredCalled = false;

      final interceptor = ErrorInterceptor(
        onShowErrorMessage: (msg) => shownMessage = msg,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      final err = DioException(
        requestOptions: RequestOptions(path: '/api/v1.0/dashboard'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/v1.0/dashboard'),
          statusCode: 401,
          data: 'Session timed out',
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(err, _TestErrorHandler((_) {}));

      expect(shownMessage, equals('Session timed out'));
      expect(sessionExpiredCalled, isTrue);
    });
  });
}

class _MockTokenProvider implements TokenProvider {
  _MockTokenProvider(
    this.token, {
    this.branchId,
  });

  final String? token;
  final dynamic branchId;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<bool> refreshToken() async => false;

  @override
  Future<void> onAuthFailed() async {}

  @override
  dynamic getBranchId() => branchId;

  @override
  void invalidateSessionCache() {}
}

class _TestRequestHandler extends RequestInterceptorHandler {
  _TestRequestHandler(this.onNext);
  final void Function(RequestOptions) onNext;

  @override
  void next(RequestOptions requestOptions) {
    onNext(requestOptions);
  }
}

class _TestErrorHandler extends ErrorInterceptorHandler {
  _TestErrorHandler(this.onNext);
  final void Function(DioException) onNext;

  @override
  void next(DioException err) {
    onNext(err);
  }
}
