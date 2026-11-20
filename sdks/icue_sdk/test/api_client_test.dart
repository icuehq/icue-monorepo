import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient & _mapDioError Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        '_mapDioError correctly extracts string messages from map error payloads',
        () {
      final dioExceptionWithStringMsg = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'message': 'Session expired. Please log in again.'},
        ),
        type: DioExceptionType.badResponse,
      );

      final error = ApiClient.mapDioErrorForTesting(dioExceptionWithStringMsg);
      expect(error.statusCode, equals(401));
      expect(error.message, equals('Session expired. Please log in again.'));
    });

    test(
        '_mapDioError safely handles non-string message types without throwing',
        () {
      final dioExceptionWithListMsg = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {
            'message': ['Field A is required', 'Field B is invalid'],
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = ApiClient.mapDioErrorForTesting(dioExceptionWithListMsg);
      expect(
        error.message,
        equals('[Field A is required, Field B is invalid]'),
      );

      final dioExceptionWithNumericMsg = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
          data: {'error': 50012},
        ),
        type: DioExceptionType.badResponse,
      );

      final error500 =
          ApiClient.mapDioErrorForTesting(dioExceptionWithNumericMsg);
      expect(error500.statusCode, equals(500));
      expect(error500.message, equals('50012'));
    });

    test('_mapDioError handles network timeouts and connection failures', () {
      final timeoutException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final timeoutError = ApiClient.mapDioErrorForTesting(timeoutException);
      expect(timeoutError.message, equals('Request timed out'));

      final connException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );
      final connError = ApiClient.mapDioErrorForTesting(connException);
      expect(connError.message, equals('No internet connection'));
    });

    test(
        'TokenRefreshInterceptor halts retry loop when icueAuthRetried is present',
        () async {
      final session = SessionService();
      session.setConfig(
        const IcueSdkConfig(apiKey: 'key', apiUser: 'user'),
      );
      await session.setIdentificationNo('student-101');

      final dio = Dio();
      final interceptor = TokenRefreshInterceptor(session, dio);

      // Create a 401 error on a request that has already been retried once
      final requestOptions = RequestOptions(
        path: '/api/v1/data',
        extra: {'icueAuthRetried': true},
      );

      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      var handlerNextCalled = false;
      var handlerResolveCalled = false;

      final handler = _TestErrorInterceptorHandler(
        onNext: (err) {
          handlerNextCalled = true;
        },
        onResolve: (res) {
          handlerResolveCalled = true;
        },
      );

      await interceptor.onError(dioError, handler);

      // Should not retry; passes error directly to handler.next
      expect(handlerNextCalled, isTrue);
      expect(handlerResolveCalled, isFalse);
    });
  });
}

class _TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  _TestErrorInterceptorHandler({
    required this.onNext,
    required this.onResolve,
  });

  final void Function(DioException err) onNext;
  final void Function(Response<dynamic> response) onResolve;

  @override
  void next(DioException err) {
    onNext(err);
  }

  @override
  void reject(DioException err, [bool? callHandler]) {
    onNext(err);
  }

  @override
  void resolve(Response<dynamic> response) {
    onResolve(response);
  }
}
