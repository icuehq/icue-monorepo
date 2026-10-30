import 'package:api_client/src/errors/api_exception.dart';
import 'package:api_client/src/errors/error_helpers.dart';
import 'package:dio/dio.dart';

typedef CrashLoggerCallback = void Function(
  String path,
  Object error,
  StackTrace? stack, {
  bool fatal,
  String? message,
});

/// Interceptor that applies error routing rules, reports unexpected crashes,
/// triggers user-facing error notifications, and converts raw [DioException]
/// into strongly-typed [ApiException].
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({
    this.onLogCrash,
    this.onShowErrorMessage,
    this.onSessionExpired,
  });

  final CrashLoggerCallback? onLogCrash;
  final void Function(String message)? onShowErrorMessage;
  final void Function()? onSessionExpired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;

    // 1. Skip standard error handling for document endpoints as in the original application
    if (path.contains('getDriverDocs') || path.contains('getVehicleDocs')) {
      handler.next(err);
      return;
    }

    // 2. Classify error and extract user-friendly message
    final isConnError = ErrorHelpers.isConnectionError(err);
    final message = ErrorHelpers.extractErrorMessage(err);

    // 3. Trigger user-facing error notification callback if configured
    onShowErrorMessage?.call(message);

    // 4. Skip reporting expected user validation & authentication errors to crash logger
    final statusCode = err.response?.statusCode;
    final isAuthOrValidationError =
        statusCode == 401 ||
        statusCode == 400 ||
        statusCode == 403 ||
        statusCode == 422 ||
        path.contains('login') ||
        path.contains('getloginotp');

    final isBadResponse = err.type == DioExceptionType.badResponse;
    if (!isAuthOrValidationError && !isConnError) {
      onLogCrash?.call(
        path,
        err,
        err.stackTrace,
        fatal: !isBadResponse,
        message: message,
      );
    }

    // 5. Handle session expiration on 401
    if (statusCode == 401) {
      onSessionExpired?.call();
    }

    // 6. Map to typed ApiException
    final apiException = _mapDioException(err, message);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
        message: apiException.message,
      ),
    );
  }

  ApiException _mapDioException(DioException err, [String? precomputedMessage]) {
    final defaultMsg = precomputedMessage ?? ErrorHelpers.extractErrorMessage(err);

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: ErrorHelpers.handleError(err) ?? defaultMsg,
          originalError: err,
        );

      case DioExceptionType.badResponse:
        final response = err.response;
        final statusCode = response?.statusCode;
        final data = response?.data;
        final serverMessage = ErrorHelpers.messageFromData(data);

        switch (statusCode) {
          case 400:
            return BadRequestException(
              message:
                  serverMessage ??
                  'Invalid request. Please check your details and try again.',
              errors: data is Map<String, dynamic> ? data : null,
              originalError: err,
            );
          case 401:
            final isLogin = _isLoginRequest(err.requestOptions);
            final message =
                isLogin &&
                    (serverMessage == null ||
                        _isGenericUnauthorized(serverMessage))
                ? 'Invalid OTP. Please check and try again.'
                : (serverMessage ??
                      'Session expired or invalid credentials. Please log in again.');
            return UnauthorizedException(message: message, originalError: err);
          case 403:
            return ForbiddenException(
              message:
                  serverMessage ??
                  'You do not have permission to perform this action.',
              originalError: err,
            );
          case 404:
            return NotFoundException(
              message:
                  serverMessage ??
                  'The requested service was not found. Please try again.',
              originalError: err,
            );
          case final int code when code >= 500 && code < 600:
            return ServerException(
              message:
                  serverMessage ??
                  'Our servers are temporarily unavailable. Please try again shortly.',
              statusCode: statusCode,
              originalError: err,
            );
          default:
            return UnknownApiException(
              message: serverMessage ?? defaultMsg,
              statusCode: statusCode,
              originalError: err,
            );
        }

      case DioExceptionType.cancel:
        return UnknownApiException(
          message: ErrorHelpers.handleError(err) ?? 'Request was cancelled.',
          originalError: err,
        );

      default:
        if (ErrorHelpers.isConnectionError(err)) {
          return NetworkException(
            message: ErrorHelpers.handleError(err) ?? defaultMsg,
            originalError: err,
          );
        }
        return UnknownApiException(
          message: defaultMsg,
          originalError: err,
        );
    }
  }

  bool _isLoginRequest(RequestOptions options) {
    final path = options.uri.path.isNotEmpty ? options.uri.path : options.path;
    final normalizedPath = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return normalizedPath.endsWith('/login') || normalizedPath == 'login';
  }

  static const _genericUnauthorized = {
    'unauthorized',
    'unauthorizedaccess',
    'invalidcredentials',
  };

  bool _isGenericUnauthorized(String message) => _genericUnauthorized.contains(
    message.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_\.]'), ''),
  );
}
