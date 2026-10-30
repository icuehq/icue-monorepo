import 'package:dio/dio.dart';

/// Utility methods for network error classification and user-friendly error message extraction.
class ErrorHelpers {
  const ErrorHelpers._();

  /// Determines user-friendly error message based on [DioExceptionType] and error details.
  static String? handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Unable to connect to the server. Please check your internet connection and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out sending data to the server. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond. Please try again later.';
      case DioExceptionType.badCertificate:
        return 'The server certificate is invalid. Please contact support.';
      case DioExceptionType.badResponse:
        return 'Received an invalid response from the server.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.connectionError:
        final errorMessage = error.message ?? '';
        if (errorMessage.contains('Failed host lookup') ||
            errorMessage.contains('nodename nor servname')) {
          return 'Unable to reach the server. Please check your internet connection and ensure the server is accessible.';
        }
        return 'Network error occurred. Please check your internet connection and try again.';
      case DioExceptionType.unknown:
        if (_isLookupFailure(error)) {
          return 'Unable to connect to the server. Please check your internet connection.';
        }
        return null;
      case DioExceptionType.transformTimeout:
        return 'Request timed out processing data. Please try again.';
    }
  }

  /// Determines if the error is a connection/network error that should be non-fatal.
  static bool isConnectionError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.type == DioExceptionType.unknown && _isLookupFailure(error));
  }

  static bool _isLookupFailure(DioException error) {
    final message = error.message ?? '';
    return message.contains('Failed host lookup') ||
        message.contains('nodename nor servname') ||
        message.contains('connection');
  }

  /// Pulls a message out of a response body ([Map] message keys or raw
  /// [String]); null when absent. HTML error pages become a generic message.
  static String? messageFromData(dynamic data) {
    final raw = data is Map
        ? data['message'] ??
              data['Message'] ??
              data['error'] ??
              data['Error'] ??
              data['errorMessage'] ??
              data['ErrorMessage'] ??
              data['msg'] ??
              data['detail']
        : data;
    if (raw is! String || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    return trimmed.startsWith('<') || trimmed.contains('<!DOCTYPE html>')
        ? 'Something went wrong...'
        : trimmed;
  }

  /// Extracts a user-friendly error message from [DioException], handling connection errors,
  /// structured server responses, and HTML error pages.
  static String extractErrorMessage(DioException error) {
    // For connection errors, prioritize user-friendly messages
    if (isConnectionError(error)) {
      final connectionMsg = handleError(error);
      if (connectionMsg != null) {
        return connectionMsg;
      }
    }

    return messageFromData(error.response?.data) ??
        error.message ??
        handleError(error) ??
        'Unexpected error occurred.';
  }
}
