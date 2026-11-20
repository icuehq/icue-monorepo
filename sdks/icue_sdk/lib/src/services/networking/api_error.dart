part of 'api_client.dart';

/// Discriminated union describing categorized API failures.
///
/// Use a `switch` on the sealed type to exhaustively handle every case:
/// ```dart
/// switch (result.error) {
///   case _NetworkError(:final message): ...
///   case _UnauthorizedError(): ...
///   case _ServerError(:final statusCode): ...
///   ...
/// }
/// ```
sealed class ApiError {
  const ApiError({required this.message, this.statusCode});

  factory ApiError.network({required String message}) = _NetworkError;
  factory ApiError.unauthorized({required String message, int? statusCode}) =
      _UnauthorizedError;
  factory ApiError.notFound({required String message}) = _NotFoundError;
  factory ApiError.server({required String message, required int statusCode}) =
      _ServerError;
  factory ApiError.cancelled() = _CancelledError;
  factory ApiError.unknown({required String message, int? statusCode}) =
      _UnknownError;

  final String message;

  /// HTTP status code, if available.
  final int? statusCode;
}

/// No connectivity or request timed out.
class _NetworkError extends ApiError {
  const _NetworkError({required super.message}) : super(statusCode: null);
}

/// Server returned 401. Token refresh already attempted and failed.
class _UnauthorizedError extends ApiError {
  const _UnauthorizedError({required super.message, super.statusCode});
}

/// Server returned 404.
class _NotFoundError extends ApiError {
  const _NotFoundError({required super.message}) : super(statusCode: 404);
}

/// Server returned 5xx.
class _ServerError extends ApiError {
  const _ServerError({required super.message, required int statusCode})
      : super(statusCode: statusCode);
}

/// Request was cancelled via [CancelToken].
class _CancelledError extends ApiError {
  const _CancelledError()
      : super(message: 'Request cancelled', statusCode: null);
}

/// Unexpected error — decoding failure, type cast, etc.
class _UnknownError extends ApiError {
  const _UnknownError({required super.message, super.statusCode});
}
