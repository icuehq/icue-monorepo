/// Base exception class for all API errors across apps.
sealed class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final dynamic originalError;

  @override
  String toString() => '$runtimeType: $message (Status: $statusCode)';
}

/// Thrown when there is no network connection or a timeout occurs.
class NetworkException extends ApiException {
  const NetworkException({
    super.message = 'Unable to connect. Please check your internet connection.',
    super.statusCode,
    super.originalError,
  });
}

/// Thrown on HTTP 400 Bad Request.
class BadRequestException extends ApiException {
  const BadRequestException({
    super.message = 'Invalid request. Please check your details and try again.',
    super.statusCode = 400,
    this.errors,
    super.originalError,
  });

  final Map<String, dynamic>? errors;
}

/// Thrown on HTTP 401 Unauthorized.
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message =
        'Session expired or invalid credentials. Please log in again.',
    super.statusCode = 401,
    super.originalError,
  });
}

/// Thrown on HTTP 403 Forbidden.
class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.statusCode = 403,
    super.originalError,
  });
}

/// Thrown on HTTP 404 Not Found.
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'The requested service was not found. Please try again.',
    super.statusCode = 404,
    super.originalError,
  });
}

/// Thrown on HTTP 500+ Server Errors.
class ServerException extends ApiException {
  const ServerException({
    super.message =
        'Our servers are temporarily unavailable. Please try again shortly.',
    super.statusCode = 500,
    super.originalError,
  });
}

/// Thrown on unexpected or unknown errors.
class UnknownApiException extends ApiException {
  const UnknownApiException({
    super.message = 'Something went wrong. Please try again.',
    super.statusCode,
    super.originalError,
  });
}
