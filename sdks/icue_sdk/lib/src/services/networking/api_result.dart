part of 'api_client.dart';

/// Wrapper for API responses that encapsulates success data, an [ApiError],
/// or a cancellation — without throwing.
///
/// Use [when] for exhaustive handling:
/// ```dart
/// result.when(
///   success: (data, statusCode) => ...,
///   failure: (error) => ...,
///   cancelled: () => ...,
/// );
/// ```
class ApiResult<T> {
  const ApiResult._({
    this.data,
    this.error,
    this.statusCode,
    this.cancelled = false,
  });

  final T? data;
  final ApiError? error;
  final int? statusCode;
  final bool cancelled;

  /// True when the request completed without an error and was not cancelled.
  bool get isSuccess => error == null && !cancelled;

  /// Constructs a successful result.
  static ApiResult<T> success<T>(T data, int? statusCode) =>
      ApiResult._(data: data, statusCode: statusCode);

  /// Constructs a failed result.
  static ApiResult<T> failure<T>(ApiError error, int? statusCode) =>
      ApiResult._(error: error, statusCode: statusCode);

  /// Constructs a cancelled result.
  static ApiResult<T> cancel<T>() =>
      ApiResult._(cancelled: true, error: ApiError.cancelled());

  /// Exhaustively handles all three outcomes.
  ///
  /// [success] receives the decoded data and HTTP status code.
  /// [failure] receives the typed [ApiError].
  /// [cancelled] is called when the request was aborted via [CancelToken].
  R when<R>({
    required R Function(T data, int? statusCode) success,
    required R Function(ApiError error) failure,
    required R Function() cancelled,
  }) {
    if (this.cancelled) return cancelled();
    if (error != null) return failure(error!);
    return success(data as T, statusCode);
  }
}
