import 'package:api_client/src/errors/api_exception.dart';

typedef ErrorReporter = void Function(
  Object error,
  StackTrace? stack,
  String? where,
);

/// Where handled errors go (an app sets it at startup, e.g. to Crashlytics).
ErrorReporter? errorReporter;

/// Reports an error a `catch` turned into a message or state. [ApiException]s
/// are skipped: `ApiClient` already showed and reported them. [where] names
/// the failed action, e.g. `DriverProvider.fetchCountries`.
void reportError(Object error, [StackTrace? stack, String? where]) {
  if (error is ApiException) return;
  errorReporter?.call(error, stack, where);
}
