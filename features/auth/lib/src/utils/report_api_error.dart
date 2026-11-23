import 'package:api_client/api_client.dart';
import 'package:icue_firebase/icue_firebase.dart';

/// `ApiClient.onLogCrash` for every app: records an unexpected API failure in
/// Crashlytics as a non-fatal. The URL is reduced to its path, since query
/// strings can carry phone numbers or tokens.
void reportApiError(
  String path,
  Object error,
  StackTrace? stack, {
  bool fatal = false,
  String? message,
}) {
  final dio = error is DioException ? error : null;
  CrashlyticsService.instance.recordError(
    error,
    stack,
    reason: 'API ${dio?.requestOptions.method ?? ''} $path: $message',
    information: [
      'status: ${dio?.response?.statusCode}',
      'type: ${dio?.type.name}',
      'path: ${dio?.requestOptions.uri.path}',
    ],
  );
}
