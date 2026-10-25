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
        final errorMessage = error.message ?? '';
        if (errorMessage.contains('Failed host lookup') ||
            errorMessage.contains('nodename nor servname') ||
            errorMessage.contains('connection')) {
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
        (error.type == DioExceptionType.unknown &&
            (error.message?.contains('Failed host lookup') == true ||
                error.message?.contains('nodename nor servname') == true ||
                error.message?.contains('connection') == true));
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

    final data = error.response?.data;
    String msg = '';
    if (data is String) {
      msg = data;
    } else if (data is Map) {
      final messageField =
          data['message'] ??
          data['Message'] ??
          data['error'] ??
          data['Error'] ??
          data['errorMessage'] ??
          data['ErrorMessage'] ??
          data['msg'] ??
          data['detail'];
      if (messageField != null) {
        msg = messageField.toString();
      }
    }

    if (msg.isEmpty) {
      msg = error.message ?? handleError(error) ?? 'Unexpected error occurred.';
    }

    return msg.contains('<!DOCTYPE html>') || msg.trim().startsWith('<')
        ? 'Something went wrong...'
        : msg;
  }
}
